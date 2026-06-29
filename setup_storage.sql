-- =============================================
-- 1. جدول الأقسام (Categories) - جديد
-- =============================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إدخال الأقسام الافتراضية
INSERT INTO public.categories (name, sort_order) VALUES
    ('ماندالا', 1),
    ('ساعات حائط', 2),
    ('جداريات طبيعة', 3),
    ('تجريد وهندسة', 4),
    ('خط عربي وإسلامي', 5)
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- 2. تفعيل RLS على جدول categories
-- =============================================
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- أي شخص يقدر يقرأ الأقسام
DROP POLICY IF EXISTS "Public read categories" ON public.categories;
CREATE POLICY "Public read categories" ON public.categories
    FOR SELECT USING (true);

-- فقط المشرف المسجل يقدر يضيف/يعدل/يحذف
DROP POLICY IF EXISTS "Auth manage categories" ON public.categories;
CREATE POLICY "Auth manage categories" ON public.categories
    FOR ALL USING (auth.role() = 'authenticated');

-- =============================================
-- 3. إصلاح سياسات جدول المنتجات (Products)
-- =============================================
-- أي شخص يقدر يقرأ المنتجات
DROP POLICY IF EXISTS "Public read products" ON public.products;
CREATE POLICY "Public read products" ON public.products
    FOR SELECT USING (true);

-- فقط المشرف المسجل يقدر يضيف/يعدل/يحذف المنتجات
DROP POLICY IF EXISTS "Auth insert products" ON public.products;
CREATE POLICY "Auth insert products" ON public.products
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth update products" ON public.products;
CREATE POLICY "Auth update products" ON public.products
    FOR UPDATE USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth delete products" ON public.products;
CREATE POLICY "Auth delete products" ON public.products
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================
-- 4. إصلاح سياسات جدول الحجوزات (Bookings)
-- =============================================
-- أي شخص يقدر يضيف حجز (العميل)
DROP POLICY IF EXISTS "Public insert bookings" ON public.bookings;
CREATE POLICY "Public insert bookings" ON public.bookings
    FOR INSERT WITH CHECK (true);

-- فقط المشرف يقدر يقرأ/يعدل/يحذف الحجوزات
DROP POLICY IF EXISTS "Auth read bookings" ON public.bookings;
CREATE POLICY "Auth read bookings" ON public.bookings
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth update bookings" ON public.bookings;
CREATE POLICY "Auth update bookings" ON public.bookings
    FOR UPDATE USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth delete bookings" ON public.bookings;
CREATE POLICY "Auth delete bookings" ON public.bookings
    FOR DELETE USING (auth.role() = 'authenticated');

-- =============================================
-- 5. إضافة عمود المقاسات لو مش موجود
-- =============================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sizes TEXT DEFAULT '';

-- =============================================
-- 6. Storage bucket للصور
-- =============================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('products-images', 'products-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read images" ON storage.objects;
CREATE POLICY "Public read images" ON storage.objects
    FOR SELECT USING (bucket_id = 'products-images');

DROP POLICY IF EXISTS "Authenticated upload images" ON storage.objects;
CREATE POLICY "Authenticated upload images" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'products-images' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated delete images" ON storage.objects;
CREATE POLICY "Authenticated delete images" ON storage.objects
    FOR DELETE USING (bucket_id = 'products-images' AND auth.role() = 'authenticated');
