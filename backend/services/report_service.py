import csv
import io
from typing import List
from sqlalchemy.orm import Session
from backend.models.transaction import Transaction
from backend.models.customer import Customer
from backend.models.scan import Scan


class ReportService:
    @staticmethod
    def generate_transactions_csv(transactions: List[Transaction]) -> str:
        """Generates a CSV string containing detailed transaction ledger records."""
        output = io.StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            "Transaction ID",
            "Date",
            "Customer Name",
            "Type",
            "Amount (INR)",
            "Source",
            "Notes",
            "Scan Entry ID"
        ])

        for tx in transactions:
            writer.writerow([
                tx.id,
                tx.date.strftime("%Y-%m-%d %H:%M:%S") if tx.date else "",
                tx.customer.name if tx.customer else "Unknown",
                tx.transaction_type,
                f"{tx.amount:.2f}",
                tx.source,
                tx.notes or "",
                tx.scan_entry_id or ""
            ])

        return output.getvalue()

    @staticmethod
    def generate_customers_csv(customers: List[Customer]) -> str:
        """Generates a CSV string with all customers, phones, and current balances."""
        output = io.StringIO()
        writer = csv.writer(output)

        writer.writerow([
            "Customer ID",
            "Customer Name",
            "Phone",
            "Outstanding Balance (INR)",
            "Total Credit Given (INR)",
            "Total Payments Received (INR)",
            "Address",
            "Notes"
        ])

        for c in customers:
            writer.writerow([
                c.id,
                c.name,
                c.phone or "",
                f"{c.credit_balance:.2f}",
                f"{c.total_credit:.2f}",
                f"{c.total_payment:.2f}",
                c.address or "",
                c.notes or ""
            ])

        return output.getvalue()
