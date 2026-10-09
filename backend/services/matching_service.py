import re
import datetime
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from backend.models.customer import Customer
from backend.models.transaction import Transaction
from backend.schemas.customer import FuzzyMatchCandidate


class MatchingService:
    @staticmethod
    def normalize_name(name: str) -> str:
        """Standardizes name for string comparison (lowercase, strips honorifics and punctuation)."""
        if not name:
            return ""
        name = name.casefold().strip()
        # Strip common Indian honorifics: ji, bhai, saheb, bhaiya, ji
        honorifics = [r"\bji\b", r"\bbhai\b", r"\bsaheb\b", r"\bbhaiya\b", r"\bseth\b", r"\bshri\b", r"\bmr\b"]
        for h in honorifics:
            name = re.sub(h, "", name)
        # Remove special characters
        name = re.sub(r"[^\w\s]", "", name, flags=re.UNICODE)
        return " ".join(name.split())

    @staticmethod
    def levenshtein_similarity(s1: str, s2: str) -> float:
        """Calculates normalized Levenshtein similarity ratio between 0.0 and 1.0."""
        if not s1 and not s2:
            return 1.0
        if not s1 or not s2:
            return 0.0
        if s1 == s2:
            return 1.0

        len_s1, len_s2 = len(s1), len(s2)
        dp = [[0] * (len_s2 + 1) for _ in range(len_s1 + 1)]

        for i in range(len_s1 + 1):
            dp[i][0] = i
        for j in range(len_s2 + 1):
            dp[0][j] = j

        for i in range(1, len_s1 + 1):
            for j in range(1, len_s2 + 1):
                cost = 0 if s1[i - 1] == s2[j - 1] else 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,      # Deletion
                    dp[i][j - 1] + 1,      # Insertion
                    dp[i - 1][j - 1] + cost  # Substitution
                )

        dist = dp[len_s1][len_s2]
        max_len = max(len_s1, len_s2)
        return round(1.0 - (dist / max_len), 3)

    @classmethod
    def token_overlap_similarity(cls, s1: str, s2: str) -> float:
        """Calculates token overlap (e.g. 'Ramesh Kumar' and 'Ramesh') for Indian naming patterns."""
        tokens1 = set(s1.split())
        tokens2 = set(s2.split())
        if not tokens1 or not tokens2:
            return 0.0
        intersection = tokens1.intersection(tokens2)
        if not intersection:
            return 0.0
        # If one is a complete prefix/subset of another (e.g. Ramesh inside Ramesh Kumar)
        return len(intersection) / min(len(tokens1), len(tokens2))

    @classmethod
    def calculate_name_similarity(cls, raw_name: str, existing_name: str) -> float:
        norm1 = cls.normalize_name(raw_name)
        norm2 = cls.normalize_name(existing_name)

        if norm1 == norm2:
            return 1.0

        lev = cls.levenshtein_similarity(norm1, norm2)
        token_sim = cls.token_overlap_similarity(norm1, norm2)

        # Composite score combining character edit distance and token subset similarity
        composite = max(lev, (lev * 0.4 + token_sim * 0.6))
        return round(composite, 3)

    @classmethod
    def find_fuzzy_matches(
        cls, db: Session, shop_id: int, extracted_name: str, threshold: float = 0.70
    ) -> List[FuzzyMatchCandidate]:
        """
        Finds existing customers in the shop who are likely matches for an extracted handwritten name.
        Does NOT automatically merge. Suggests candidates to the shopkeeper.
        """
        customers = db.query(Customer).filter(Customer.shop_id == shop_id, Customer.is_active == True).all()
        candidates = []

        for cust in customers:
            sim = cls.calculate_name_similarity(extracted_name, cust.name)
            if sim >= threshold:
                candidates.append(
                    FuzzyMatchCandidate(
                        customer_id=cust.id,
                        customer_name=cust.name,
                        phone=cust.phone,
                        similarity_score=sim,
                        current_balance=cust.credit_balance,
                        match_reason=f"Similar to '{cust.name}' ({int(sim * 100)}% match)",
                    )
                )

        # Sort highest similarity first
        candidates.sort(key=lambda x: x.similarity_score, reverse=True)
        return candidates


    @classmethod
    def best_fuzzy_match(
        cls, db: Session, shop_id: int, extracted_name: str, threshold: float = 0.75
    ) -> Optional[Tuple[Customer, float]]:
        """Return the strongest existing customer match only when confidence is high enough."""
        clean = (extracted_name or "").strip()
        if not clean:
            return None

        customers = db.query(Customer).filter(
            Customer.shop_id == shop_id,
            Customer.is_active == True,
        ).all()

        ranked = []
        for customer in customers:
            score = cls.calculate_name_similarity(clean, customer.name)
            ranked.append((customer, score))

        ranked.sort(key=lambda item: item[1], reverse=True)
        if not ranked or ranked[0][1] < threshold:
            return None

        # If two customers are almost equally similar, do not silently merge.
        if len(ranked) > 1 and ranked[0][1] - ranked[1][1] < 0.05 and ranked[1][1] >= threshold:
            return None

        return ranked[0]

    @classmethod
    def repair_ai_transaction_links(cls, db: Session, shop_id: int) -> int:
        """Repair old AI transactions that were attached to a duplicate OCR-created customer."""
        txs = (
            db.query(Transaction)
            .filter(Transaction.shop_id == shop_id, Transaction.source == "AI_SCAN")
            .all()
        )
        changed = 0
        for tx in txs:
            entry = tx.scan_entry
            if not entry or not entry.extracted_customer_name:
                continue

            best = cls.best_fuzzy_match(
                db=db, shop_id=shop_id, extracted_name=entry.extracted_customer_name, threshold=0.75
            )
            if not best:
                continue

            customer, _score = best
            if customer.id == tx.customer_id:
                continue

            old_customer = db.query(Customer).filter(Customer.id == tx.customer_id).first()
            tx.customer_id = customer.id
            if old_customer:
                old_customer.recalculate_balance()
            customer.recalculate_balance()
            changed += 1

        if changed:
            db.flush()
            # Recalculate every affected customer's totals from authoritative transactions.
            affected_ids = {tx.customer_id for tx in txs if tx.customer_id}
            for customer_id in affected_ids:
                affected = db.query(Customer).filter(Customer.id == customer_id).first()
                if affected:
                    affected.recalculate_balance()
            db.commit()
        return changed

    @classmethod
    def check_duplicate_transaction(
        cls,
        db: Session,
        shop_id: int,
        customer_id: int,
        amount: float,
        date: datetime.datetime,
        tx_type: str,
        proximity_hours: int = 24,
    ) -> Tuple[bool, Optional[Transaction], str]:
        """
        Checks if a transaction with identical customer, amount, type, and proximate date already exists.
        Prevents accidental double-entries from re-scanning pages.
        """
        if not date:
            date = datetime.datetime.utcnow()

        start_window = date - datetime.timedelta(hours=proximity_hours)
        end_window = date + datetime.timedelta(hours=proximity_hours)

        existing = (
            db.query(Transaction)
            .filter(
                Transaction.shop_id == shop_id,
                Transaction.customer_id == customer_id,
                Transaction.amount == amount,
                Transaction.transaction_type == tx_type,
                Transaction.date >= start_window,
                Transaction.date <= end_window,
            )
            .first()
        )

        if existing:
            msg = (
                f"Possible duplicate detected: Transaction #{existing.id} with same amount (₹{amount}) "
                f"and type ({tx_type}) exists on {existing.date.strftime('%d %b %Y')}."
            )
            return True, existing, msg

        return False, None, ""
