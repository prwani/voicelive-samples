from aiohttp import web
import sqlite3
import json
import random
from datetime import datetime
import os
from phone_utils import normalize_phone_number

# Database file path
DB_PATH = os.path.join(os.path.dirname(__file__), 'payment_db.sqlite')

async def submit_payment(request):
    """Handle payment submission with simple SQL query."""
    try:
        data = await request.json()
        
        policy_number = data.get('policy_number', '')
        phone_number = data.get('phone_number', '')
        amount_due = data.get('amount_due', 0)
        payment_date = data.get('payment_date', '')
        
        # Normalize phone number to +91-XXXXXXXXXX format
        normalized_phone = normalize_phone_number(phone_number)
        if not normalized_phone:
            return web.json_response({
                'success': False,
                'error': 'Invalid phone number format'
            }, status=400)
        
        payment_status = 'completed'
        
        # Use simple SQL INSERT query
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO customer_payment_details 
            (policy_number, phone_number, amount_due, payment_date, payment_status)
            VALUES (?, ?, ?, ?, ?)
        ''', (policy_number, normalized_phone, amount_due, payment_date, payment_status))
        
        conn.commit()
        conn.close()
        
        return web.json_response({
            'success': True,
            'message': 'Payment recorded successfully'
        })
        
    except Exception as e:
        return web.json_response({
            'success': False,
            'error': str(e)
        }, status=500)

async def get_payments(request):
    """Retrieve all payment records with simple SQL query."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM customer_payment_details ORDER BY id DESC')
        
        rows = cursor.fetchall()
        conn.close()
        
        # Convert rows to list of dictionaries
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
        
        return web.json_response({'payments': payments})
        
    except Exception as e:
        return web.json_response({
            'success': False,
            'error': str(e)
        }, status=500)
