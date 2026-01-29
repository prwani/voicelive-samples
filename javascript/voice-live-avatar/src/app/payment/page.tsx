'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { normalizePhoneNumber } from '@/lib/phoneUtils';

export default function PaymentPage() {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [normalizedPhoneNumber, setNormalizedPhoneNumber] = useState('');
  const [amountDue] = useState('57,371');
  const [dueDate, setDueDate] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    // Get phone number from query string and normalize it
    const params = new URLSearchParams(window.location.search);
    const phone = params.get('phone') || '';
    const normalized = normalizePhoneNumber(phone);
    setPhoneNumber(phone);
    setNormalizedPhoneNumber(normalized);

    // Calculate due date (10 days from today)
    const today = new Date();
    today.setDate(today.getDate() + 10);
    const formatted = today.toLocaleDateString('en-GB', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
    setDueDate(formatted);
  }, []);

  const handlePayment = async () => {
    setIsSubmitting(true);
    setMessage('');

    try {
      const response = await fetch('/api/payment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phone_number: normalizedPhoneNumber,
          amount_due: 57371,
          payment_date: new Date().toISOString().split('T')[0]
        }),
      });

      const data = await response.json();

      if (data.success) {
        setMessage(`Payment successful! Customer ID: ${data.customer_id}`);
      } else {
        setMessage(`Error: ${data.error || 'Payment failed'}`);
      }
    } catch (error) {
      setMessage(`Error: ${error instanceof Error ? error.message : 'Payment failed'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-3xl font-bold text-blue-900">
            Contoso Insurance
          </CardTitle>
          <p className="text-lg text-blue-600 mt-2">Premium Payment</p>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="phone">Phone Number</Label>
            <Input
              id="phone"
              type="text"
              value={normalizedPhoneNumber || phoneNumber}
              readOnly
              className="bg-gray-100"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="amount">Amount Due</Label>
            <div className="flex items-center gap-2">
              <Input
                id="amount"
                type="text"
                value={`Rs. ${amountDue}`}
                readOnly
                className="bg-gray-100"
              />
              <span className="text-sm text-gray-600 whitespace-nowrap">
                Including GST
              </span>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="dueDate">Due Date</Label>
            <Input
              id="dueDate"
              type="text"
              value={dueDate}
              readOnly
              className="bg-gray-100"
            />
          </div>

          <Button
            onClick={handlePayment}
            disabled={isSubmitting}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white"
          >
            {isSubmitting ? 'Processing...' : 'Complete Payment'}
          </Button>

          {message && (
            <div
              className={`p-3 rounded-md text-sm ${
                message.includes('successful')
                  ? 'bg-green-100 text-green-800'
                  : 'bg-red-100 text-red-800'
              }`}
            >
              {message}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
