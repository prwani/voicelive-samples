"""
Phone number normalization utility for consistent formatting.
"""

def normalize_phone_number(phone_number: str) -> str:
    """
    Normalizes a phone number to the format: +91-XXXXXXXXXX
    Accepts various input formats:
    - 10 digits: 7045289568 -> +91-7045289568
    - 12 digits with country code: 917045289568 -> +91-7045289568
    - Up to 15 characters with symbols: +91-7045289568, +917045289568, 91-7045289568, etc.
    
    Args:
        phone_number: The phone number input from user
        
    Returns:
        Normalized phone number in format +91-XXXXXXXXXX or empty string if invalid
    """
    if not phone_number:
        return ""
    
    # Remove all non-digit characters to get just the numbers
    digits_only = ''.join(filter(str.isdigit, phone_number))
    
    # Extract the last 10 digits (the actual phone number)
    if len(digits_only) == 10:
        # Just 10 digits provided
        last_10_digits = digits_only
    elif len(digits_only) >= 11:
        # 11+ digits provided, take last 10
        last_10_digits = digits_only[-10:]
    else:
        # Less than 10 digits, invalid
        return ""
    
    # Return in the format +91-XXXXXXXXXX
    return f"+91-{last_10_digits}"


def is_valid_phone_number(phone_number: str) -> bool:
    """
    Validates if a phone number can be normalized
    
    Args:
        phone_number: The phone number input from user
        
    Returns:
        True if the phone number is valid (can be normalized), False otherwise
    """
    if not phone_number:
        return False
    
    digits_only = ''.join(filter(str.isdigit, phone_number))
    
    # Must have at least 10 digits and at most 15 characters total
    return len(digits_only) >= 10 and len(phone_number) <= 15
