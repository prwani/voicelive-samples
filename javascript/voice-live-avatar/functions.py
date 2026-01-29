import os
import sqlite3
from phone_utils import normalize_phone_number

connection_string = os.getenv("COMMUNICATION_SERVICES_CONNECTION_STRING")
channelRegistrationId = os.getenv("WHATSAPP_CHANNEL_ID")

# Database file path
DB_PATH = os.path.join(os.path.dirname(__file__), 'payment_db.sqlite')

def send_text_message(phone_number : str, base_url: str = ""):
    from azure.communication.messages import NotificationMessagesClient
    from azure.communication.messages.models import ( TextNotificationContent )

    # Normalize phone number to +91-XXXXXXXXXX format
    normalized_phone = normalize_phone_number(phone_number)
    if not normalized_phone:
        print(f"Invalid phone number provided: {phone_number}")
        return {"error": "Invalid phone number format"}

    # client creation
    messaging_client = NotificationMessagesClient.from_connection_string(connection_string)

    payment_url = f"{base_url}/payment?phone={normalized_phone}" if base_url else f"/payment?phone={normalized_phone}"
    
    text_options = TextNotificationContent (
        channel_registration_id=channelRegistrationId,
        to= [normalized_phone],
        content=f"Your policy premium payment is due in next few days. Pay here {payment_url}",
    )
    
    # calling send() with WhatsApp message details
    message_responses = messaging_client.send(text_options)
    response = message_responses.receipts[0]
    
    if (response is not None):
        print("WhatsApp Text Message with message id {} was successfully sent to {}"
        .format(response.message_id, response.to))
    else:
        print("Message failed to send")


def check_payment_in_db(phone_number: str) -> dict:
    """Check if a payment record exists for the given phone number in the database.
    
    Args:
        phone_number: The phone number to search for in the database.
        
    Returns:
        A dictionary containing:
        - found: Boolean indicating if a payment record was found
        - payment_details: List of payment records if found, empty list otherwise
        - message: A descriptive message about the result
    """
    # Normalize phone number to +91-XXXXXXXXXX format
    normalized_phone = normalize_phone_number(phone_number)
    if not normalized_phone:
        return {
            'found': False,
            'payment_details': [],
            'message': f"Invalid phone number format: {phone_number}"
        }
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, policy_number, phone_number, amount_due, payment_date, payment_status
            FROM customer_payment_details
            WHERE phone_number = ?
            ORDER BY id DESC
        ''', (normalized_phone,))
        
        rows = cursor.fetchall()
        conn.close()
        
        if rows:
            payments = []
            for row in rows:
                payments.append({
                    'id': row[0],
                    'policy_number': row[1],
                    'phone_number': row[2],
                    'amount_due': row[3],
                    'payment_date': row[4],
                    'payment_status': row[5]
                })
            
            return {
                'found': True,
                'payment_details': payments,
                'message': f"Found {len(payments)} payment record(s) for phone number {normalized_phone}"
            }
        else:
            return {
                'found': False,
                'payment_details': [],
                'message': f"No payment records found for phone number {normalized_phone}"
            }
            
    except Exception as e:
        return {
            'found': False,
            'payment_details': [],
            'message': f"Error checking payment records: {str(e)}"
        }


