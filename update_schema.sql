-- ============================================================
-- 1. إنشاء جدول المنتجات (products) إذا لم يكن موجوداً
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    price NUMERIC NOT NULL,
    original_price NUMERIC,
    specifications TEXT,
    description TEXT,
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 2. إنشاء جدول الحجوزات (bookings) إذا لم يكن موجوداً
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name TEXT NOT NULL,
    whatsapp TEXT NOT NULL,
    governorate TEXT NOT NULL,
    product_title TEXT NOT NULL,
    notes TEXT,
    status TEXT DEFAULT 'جديد' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 3. ترقية وإضافة الأعمدة الجديدة لجدول الحجوزات
-- ============================================================
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS coupon_code TEXT DEFAULT '';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS final_price NUMERIC DEFAULT 0;

-- ============================================================
-- 4. إنشاء وترقية جدول الكوبونات (coupons)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    discount_type TEXT DEFAULT 'percentage',
    discount_value NUMERIC NOT NULL DEFAULT 10,
    max_uses INTEGER DEFAULT NULL,
    current_uses INTEGER DEFAULT 0,
    valid_until TIMESTAMPTZ DEFAULT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة أي أعمدة مفقودة في حال كان جدول الكوبونات قديماً
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS discount_type TEXT DEFAULT 'percentage';
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS discount_value NUMERIC DEFAULT 10;
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS max_uses INTEGER DEFAULT NULL;
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS current_uses INTEGER DEFAULT 0;
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.coupons ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- ============================================================
-- 5. إنشاء وترقية جدول التقييمات والأقسام (reviews & categories)
-- ============================================================
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

-- إضافة أعمدة مفقودة لجدول التقييمات
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS product_title TEXT;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT false;

CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة أعمدة مفقودة للأقسام
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- ============================================================
-- 6. تفعيل وتحديث سياسات الحماية (RLS) لكل الجداول
-- ============================================================
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- سياسات المنتجات (Products)
DROP POLICY IF EXISTS "Allow public read access to products" ON public.products;
DROP POLICY IF EXISTS "Public read products" ON public.products;
CREATE POLICY "Public read products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to products" ON public.products;
DROP POLICY IF EXISTS "Auth insert products" ON public.products;
DROP POLICY IF EXISTS "Auth update products" ON public.products;
DROP POLICY IF EXISTS "Auth delete products" ON public.products;
CREATE POLICY "Auth manage products" ON public.products FOR ALL USING (auth.role() = 'authenticated');

-- سياسات الحجوزات (Bookings)
DROP POLICY IF EXISTS "Allow public insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Public insert bookings" ON public.bookings;
CREATE POLICY "Allow public insert bookings" ON public.bookings FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin full access to bookings" ON public.bookings;
CREATE POLICY "Admin full access to bookings" ON public.bookings FOR ALL USING (auth.jwt() ->> 'email' IN ('yousifadel9990@gmail.com', 'admin@elnour.com'));

DROP POLICY IF EXISTS "Users view own bookings" ON public.bookings;
CREATE POLICY "Users view own bookings" ON public.bookings FOR SELECT USING (auth.uid() = user_id);

-- سياسات الكوبونات (Coupons)
DROP POLICY IF EXISTS "Public read active coupons" ON public.coupons;
CREATE POLICY "Public read active coupons" ON public.coupons FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Auth manage coupons" ON public.coupons;
CREATE POLICY "Auth manage coupons" ON public.coupons FOR ALL USING (auth.role() = 'authenticated');

-- سياسات التقييمات (Reviews)
DROP POLICY IF EXISTS "Public insert reviews" ON public.reviews;
CREATE POLICY "Public insert reviews" ON public.reviews FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public read approved reviews" ON public.reviews;
CREATE POLICY "Public read approved reviews" ON public.reviews FOR SELECT USING (is_approved = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth manage reviews" ON public.reviews;
CREATE POLICY "Auth manage reviews" ON public.reviews FOR ALL USING (auth.role() = 'authenticated');

-- سياسات الأقسام (Categories)
DROP POLICY IF EXISTS "Public read categories" ON public.categories;
CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Auth manage categories" ON public.categories;
CREATE POLICY "Auth manage categories" ON public.categories FOR ALL USING (auth.role() = 'authenticated');

-- ============================================================
-- 7. إدخال الأقسام والكوبونات الافتراضية
-- ============================================================
INSERT INTO public.categories (name, sort_order) VALUES
    ('ماندالا', 1),
    ('ساعات حائط', 2),
    ('جداريات طبيعة', 3),
    ('تجريد وهندسة', 4),
    ('خط عربي وإسلامي', 5)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.coupons (code, discount_type, discount_value, max_uses)
VALUES ('ELNOUR10', 'percentage', 10, 50)
ON CONFLICT (code) DO NOTHING;
