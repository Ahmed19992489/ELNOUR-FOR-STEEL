-- =============================================
-- 1. جدول الكوبونات (Coupons)
-- =============================================
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    discount_type TEXT DEFAULT 'percentage', -- 'percentage' or 'fixed'
    discount_value NUMERIC NOT NULL DEFAULT 10,
    max_uses INTEGER DEFAULT NULL,           -- NULL = unlimited
    current_uses INTEGER DEFAULT 0,
    valid_until TIMESTAMPTZ DEFAULT NULL,    -- NULL = no expiry
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS للكوبونات
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active coupons" ON public.coupons;
CREATE POLICY "Public read active coupons" ON public.coupons
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Auth manage coupons" ON public.coupons;
CREATE POLICY "Auth manage coupons" ON public.coupons
    FOR ALL USING (auth.role() = 'authenticated');

-- كوبون تجريبي
INSERT INTO public.coupons (code, discount_type, discount_value, max_uses)
VALUES ('ELNOUR10', 'percentage', 10, 50)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 2. جدول التقييمات (Reviews)
-- =============================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    product_title TEXT,
    customer_name TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    comment TEXT,
    is_approved BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS للتقييمات
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- العملاء يقدرون يضيفون تقييم
DROP POLICY IF EXISTS "Public insert reviews" ON public.reviews;
CREATE POLICY "Public insert reviews" ON public.reviews
    FOR INSERT WITH CHECK (true);

-- العملاء يقدرون يقرأون التقييمات المعتمدة فقط
DROP POLICY IF EXISTS "Public read approved reviews" ON public.reviews;
CREATE POLICY "Public read approved reviews" ON public.reviews
    FOR SELECT USING (is_approved = true OR auth.role() = 'authenticated');

-- الأدمن يقدر يعدل ويحذف
DROP POLICY IF EXISTS "Auth manage reviews" ON public.reviews;
CREATE POLICY "Auth manage reviews" ON public.reviews
    FOR ALL USING (auth.role() = 'authenticated');

-- =============================================
-- 3. إضافة عمود discount_applied للحجوزات
-- =============================================
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS coupon_code TEXT DEFAULT '';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS final_price NUMERIC DEFAULT 0;
