```rust
INSERT INTO invoice_payment (invoice_id, paid_on, amount, currency, final_amount, mode, comments) VALUES
(1, '2024-04-01', 500.00, 'USD', 500.00, 'Credit Card', 'Paid in full'),
(2, '2024-04-02', 350.00, 'EUR', 315.00, 'Bank Transfer', NULL),
(3, '2024-04-03', 750.00, 'GBP', 750.00, 'Cash', 'Received by John Doe'),
(4, '2024-04-04', 200.00, 'USD', 200.00, 'PayPal', NULL),
(5, '2024-04-05', 1000.00, 'EUR', 920.00, 'Cheque', 'Check number: 123456'),
(6, '2024-04-06', 600.00, 'USD', 600.00, 'Credit Card', 'Transaction ID: 789012'),
(7, '2024-04-07', 450.00, 'GBP', 450.00, 'Bank Transfer', NULL),
(8, '2024-04-08', 800.00, 'EUR', 720.00, 'Cash', NULL),
(9, '2024-04-09', 300.00, 'USD', 300.00, 'PayPal', NULL),
(10, '2024-04-10', 550.00, 'GBP', 550.00, 'Credit Card', NULL);

```
