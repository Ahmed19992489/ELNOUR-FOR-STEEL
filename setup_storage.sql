-- أضف عمود المقاسات لجدول المنتجات
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sizes TEXT DEFAULT '';

-- أنشئ بكت الصور في Supabase Storage
INSERT INTO storage.buckets (id, name, public) 
VALUES ('products-images', 'products-images', true)
ON CONFLICT (id) DO NOTHING;

-- سياسات الوصول للبكت
CREATE POLICY IF NOT EXISTS "Public read images" ON storage.objects 
    FOR SELECT USING (bucket_id = 'products-images');

CREATE POLICY IF NOT EXISTS "Authenticated upload images" ON storage.objects 
    FOR INSERT WITH CHECK (bucket_id = 'products-images' AND auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Authenticated delete images" ON storage.objects 
    FOR DELETE USING (bucket_id = 'products-images' AND auth.role() = 'authenticated');
