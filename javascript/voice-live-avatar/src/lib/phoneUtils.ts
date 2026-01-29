/**
 * Normalizes a phone number to the format: +91-XXXXXXXXXX
 * Accepts various input formats:
 * - 10 digits: 7045289568 -> +91-7045289568
 * - 12 digits with country code: 917045289568 -> +91-7045289568
 * - Up to 15 characters with symbols: +91-7045289568, +917045289568, 91-7045289568, etc.
 * 
 * @param phoneNumber The phone number input from user
 * @returns Normalized phone number in format +91-XXXXXXXXXX or empty string if invalid
 */
export function normalizePhoneNumber(phoneNumber: string): string {
  if (!phoneNumber) {
    return "";
  }

  // Remove all non-digit characters to get just the numbers
  const digitsOnly = phoneNumber.replace(/\D/g, "");

  // Extract the last 10 digits (the actual phone number)
  let last10Digits = "";
  
  if (digitsOnly.length === 10) {
    // Just 10 digits provided
    last10Digits = digitsOnly;
  } else if (digitsOnly.length >= 11) {
    // 11+ digits provided, take last 10
    last10Digits = digitsOnly.slice(-10);
  } else {
    // Less than 10 digits, invalid
    return "";
  }

  // Return in the format +91-XXXXXXXXXX
  return `+91-${last10Digits}`;
}

/**
 * Validates if a phone number can be normalized
 * @param phoneNumber The phone number input from user
 * @returns true if the phone number is valid (can be normalized), false otherwise
 */
export function isValidPhoneNumber(phoneNumber: string): boolean {
  if (!phoneNumber) {
    return false;
  }

  const digitsOnly = phoneNumber.replace(/\D/g, "");
  
  // Must have at least 10 digits and at most 15 characters total
  return digitsOnly.length >= 10 && phoneNumber.length <= 15;
}
