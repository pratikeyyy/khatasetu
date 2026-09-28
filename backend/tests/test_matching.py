import pytest
from backend.services.matching_service import MatchingService


def test_name_similarity_variations():
    # 1. Exact match with case difference
    assert MatchingService.calculate_name_similarity("Ramesh", "ramesh") == 1.0

    # 2. Name with honorific 'Ji'
    sim_ji = MatchingService.calculate_name_similarity("Ramesh Ji", "Ramesh")
    assert sim_ji >= 0.90

    # 3. Name with honorific 'Bhai'
    sim_bhai = MatchingService.calculate_name_similarity("Suresh Bhai", "Suresh")
    assert sim_bhai >= 0.90

    # 4. First name vs Full name (token subset)
    sim_full = MatchingService.calculate_name_similarity("Ramesh", "Ramesh Kumar")
    assert sim_full >= 0.70

    # 5. Completely different names
    sim_diff = MatchingService.calculate_name_similarity("Ramesh Kumar", "Anita Devi")
    assert sim_diff < 0.30


def test_levenshtein_similarity():
    # Single character typo
    sim_typo = MatchingService.levenshtein_similarity("Ramesh", "Rameesh")
    assert sim_typo >= 0.85

    # Completely different strings
    sim_diff = MatchingService.levenshtein_similarity("Ramesh", "Vikram")
    assert sim_diff < 0.50
