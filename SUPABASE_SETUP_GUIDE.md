# Supabase Setup Guide for Services & Subscriptions

## Database Setup

### 1. Create `service_pricing` Table

```sql
CREATE TABLE public.service_pricing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    service_name TEXT NOT NULL,
    tier TEXT NOT NULL DEFAULT 'SEDAN (A)',
    plan_type TEXT NOT NULL CHECK (plan_type IN ('One-Time', 'Monthly', 'Yearly')),
    price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_special BOOLEAN DEFAULT false,
    is_subscription_eligible BOOLEAN DEFAULT true,
    subtitle TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_plan_type ON service_pricing(plan_type);
CREATE INDEX idx_is_active ON service_pricing(is_active);
CREATE INDEX idx_tier ON service_pricing(tier);
CREATE INDEX idx_category ON service_pricing(category);
```

### 2. Sample Data - One-Time Services

```sql
INSERT INTO service_pricing (category, service_name, tier, plan_type, price, is_active, display_order) VALUES
('Car Wash', 'Basic Exterior Wash', 'SEDAN (A)', 'One-Time', 25.00, true, 1),
('Car Wash', 'Basic Exterior Wash', 'SUV (B)', 'One-Time', 30.00, true, 1),
('Car Wash', 'Basic Exterior Wash', 'LUX (C)', 'One-Time', 35.00, true, 1),

('Car Wash', 'Premium Wash', 'SEDAN (A)', 'One-Time', 45.00, true, 2),
('Car Wash', 'Premium Wash', 'SUV (B)', 'One-Time', 55.00, true, 2),
('Car Wash', 'Premium Wash', 'LUX (C)', 'One-Time', 65.00, true, 2),

('Detailing', 'Full Interior Detail', 'SEDAN (A)', 'One-Time', 75.00, true, 1),
('Detailing', 'Full Interior Detail', 'SUV (B)', 'One-Time', 95.00, true, 1),
('Detailing', 'Full Interior Detail', 'LUX (C)', 'One-Time', 125.00, true, 1),

('Detailing', 'Exterior Detail', 'SEDAN (A)', 'One-Time', 65.00, true, 2),
('Detailing', 'Exterior Detail', 'SUV (B)', 'One-Time', 80.00, true, 2),
('Detailing', 'Exterior Detail', 'LUX (C)', 'One-Time', 100.00, true, 2),

('Maintenance', 'Paint Protection', 'SEDAN (A)', 'One-Time', 150.00, true, 1, true),
('Maintenance', 'Paint Protection', 'SUV (B)', 'One-Time', 200.00, true, 1, true),
('Maintenance', 'Paint Protection', 'LUX (C)', 'One-Time', 250.00, true, 1, true),

('Maintenance', 'Ceramic Coating', 'SEDAN (A)', 'One-Time', 300.00, true, 2, true),
('Maintenance', 'Ceramic Coating', 'SUV (B)', 'One-Time', 400.00, true, 2, true),
('Maintenance', 'Ceramic Coating', 'LUX (C)', 'One-Time', 500.00, true, 2, true);
```

### 3. Sample Data - Monthly Subscriptions

```sql
INSERT INTO service_pricing (category, service_name, tier, plan_type, price, is_active, display_order, subtitle) VALUES
('Car Wash', 'Basic Monthly', 'SEDAN (A)', 'Monthly', 49.99, true, 1, '2 Washes/Month'),
('Car Wash', 'Basic Monthly', 'SUV (B)', 'Monthly', 59.99, true, 1, '2 Washes/Month'),
('Car Wash', 'Basic Monthly', 'LUX (C)', 'Monthly', 69.99, true, 1, '2 Washes/Month'),

('Car Wash', 'Premium Monthly', 'SEDAN (A)', 'Monthly', 79.99, true, 2, 'Unlimited Washes + 10% Off'),
('Car Wash', 'Premium Monthly', 'SUV (B)', 'Monthly', 99.99, true, 2, 'Unlimited Washes + 10% Off'),
('Car Wash', 'Premium Monthly', 'LUX (C)', 'Monthly', 129.99, true, 2, 'Unlimited Washes + 10% Off'),

('Car Wash', 'Luxury Monthly', 'SEDAN (A)', 'Monthly', 129.99, true, 3, 'Unlimited + Detailing + Priority', true),
('Car Wash', 'Luxury Monthly', 'SUV (B)', 'Monthly', 159.99, true, 3, 'Unlimited + Detailing + Priority', true),
('Car Wash', 'Luxury Monthly', 'LUX (C)', 'Monthly', 199.99, true, 3, 'Unlimited + Detailing + Priority', true);
```

### 4. Sample Data - Yearly Subscriptions

```sql
INSERT INTO service_pricing (category, service_name, tier, plan_type, price, is_active, display_order, subtitle) VALUES
('Car Wash', 'Basic Yearly', 'SEDAN (A)', 'Yearly', 499.99, true, 1, 'Save $99/Year'),
('Car Wash', 'Basic Yearly', 'SUV (B)', 'Yearly', 599.99, true, 1, 'Save $119/Year'),
('Car Wash', 'Basic Yearly', 'LUX (C)', 'Yearly', 699.99, true, 1, 'Save $139/Year'),

('Car Wash', 'Premium Yearly', 'SEDAN (A)', 'Yearly', 799.99, true, 2, 'Save $199/Year'),
('Car Wash', 'Premium Yearly', 'SUV (B)', 'Yearly', 999.99, true, 2, 'Save $299/Year'),
('Car Wash', 'Premium Yearly', 'LUX (C)', 'Yearly', 1299.99, true, 2, 'Save $459/Year'),

('Car Wash', 'Luxury Yearly', 'SEDAN (A)', 'Yearly', 1299.99, true, 3, 'Save $259/Year', true),
('Car Wash', 'Luxury Yearly', 'SUV (B)', 'Yearly', 1599.99, true, 3, 'Save $319/Year', true),
('Car Wash', 'Luxury Yearly', 'LUX (C)', 'Yearly', 1999.99, true, 3, 'Save $399/Year', true);
```

---

## RLS Policies

### Public Access (Customers)

```sql
-- Customers can view active services
CREATE POLICY "Allow viewing active services"
    ON public.service_pricing
    FOR SELECT
    USING (is_active = true);
```

### Admin Access

```sql
-- Admins can do everything
CREATE POLICY "Allow admin full access"
    ON public.service_pricing
    USING (auth.uid() IN (
        SELECT id FROM auth.users WHERE email LIKE '%@admin%'
    ));
```

---

## Triggers

### Auto-update `updated_at` on changes

```sql
CREATE OR REPLACE FUNCTION update_service_pricing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_service_pricing_updated_at
    BEFORE UPDATE ON public.service_pricing
    FOR EACH ROW
    EXECUTE FUNCTION update_service_pricing_updated_at();
```

---

## Views (Optional)

### View for One-Time Services

```sql
CREATE VIEW one_time_services AS
SELECT * FROM service_pricing
WHERE plan_type = 'One-Time' AND is_active = true
ORDER BY display_order ASC;
```

### View for Monthly Plans

```sql
CREATE VIEW monthly_plans AS
SELECT * FROM service_pricing
WHERE plan_type = 'Monthly' AND is_active = true
ORDER BY display_order ASC;
```

### View for Yearly Plans

```sql
CREATE VIEW yearly_plans AS
SELECT * FROM service_pricing
WHERE plan_type = 'Yearly' AND is_active = true
ORDER BY display_order ASC;
```

---

## Performance Tuning

### Create Composite Index

```sql
CREATE INDEX idx_service_pricing_active_type 
ON service_pricing(is_active, plan_type, display_order);
```

### Query Optimization for Apps

```sql
-- Efficient one-time services query
SELECT id, service_name, tier, price, is_special, subtitle
FROM service_pricing
WHERE plan_type = 'One-Time' 
  AND is_active = true
ORDER BY display_order ASC;

-- Efficient subscription query
SELECT id, service_name, tier, price, subtitle
FROM service_pricing
WHERE plan_type = ? -- 'Monthly' or 'Yearly'
  AND is_active = true
ORDER BY display_order ASC;
```

---

## Backup & Restore

### Backup service_pricing table

```bash
# Using pg_dump
pg_dump -U postgres -d your_db -t service_pricing > service_pricing_backup.sql
```

### Restore service_pricing table

```bash
# Using psql
psql -U postgres -d your_db < service_pricing_backup.sql
```

---

## Monitoring & Analytics

### Monitor table size

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename = 'service_pricing';
```

### Analyze service popularity

```sql
SELECT 
    plan_type,
    COUNT(*) as total_services,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM service_pricing
WHERE is_active = true
GROUP BY plan_type;
```

---

## API Endpoints (For External Integration)

### Get all one-time services

```
GET /rest/v1/rpc/get_one_time_services
```

### Get monthly plans

```
GET /rest/v1/rpc/get_monthly_plans
```

### Get yearly plans

```
GET /rest/v1/rpc/get_yearly_plans
```

### Create new service (admin only)

```
POST /rest/v1/service_pricing
Body: {
    "category": "Car Wash",
    "service_name": "Express Wash",
    "tier": "SEDAN (A)",
    "plan_type": "One-Time",
    "price": 20.00
}
```

---

## Troubleshooting

### Services not showing

1. Check `is_active = true`
2. Verify `plan_type` matches filter
3. Confirm RLS policies allow viewing
4. Check network requests in browser console

### Pricing not updating

1. Verify `updated_at` timestamp changes
2. Check if trigger is firing
3. Confirm write permissions in RLS

### Slow queries

1. Check if indexes exist
2. Analyze query performance with `EXPLAIN`
3. Consider pagination for large result sets

---

## Migration from Old System

If you have existing services:

```sql
-- Copy from old table to new schema
INSERT INTO service_pricing (
    category,
    service_name,
    tier,
    plan_type,
    price,
    is_active
)
SELECT 
    category,
    name,
    tier,
    'One-Time',  -- Set default plan type
    price,
    active
FROM old_services;
```

---

## Exporting Data

### Export to CSV

```bash
\COPY service_pricing TO 'services.csv' CSV HEADER;
```

### Export to JSON

```sql
SELECT json_agg(row_to_json(t)) FROM service_pricing t;
```
