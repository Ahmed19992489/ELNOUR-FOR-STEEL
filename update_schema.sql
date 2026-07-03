-- ============================================================
-- 1. إضافة أعمدة البريد الإلكتروني والربط بحساب المستخدم
-- ============================================================
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ============================================================
-- 2. تحديث سياسات الحماية RLS لجدول الحجوزات (bookings)
-- ============================================================
-- إزالة السياسات القديمة التي كانت تمنح أي مستخدم مسجل وصولاً كاملاً
DROP POLICY IF EXISTS "Allow authenticated users full access to bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow public insert access to bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow public insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Admin full access to bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users view own bookings" ON public.bookings;

-- سياسة 1: السماح للعامة (الزوار والعملاء) بإرسال طلب حجز جديد
CREATE POLICY "Allow public insert bookings" ON public.bookings
    FOR INSERT WITH CHECK (true);

-- سياسة 2: السماح للأدمن (صاحب البريد المذكور) بالتحكم الكامل في جميع الحجوزات
CREATE POLICY "Admin full access to bookings" ON public.bookings
    FOR ALL USING (auth.jwt() ->> 'email' IN ('yousifadel9990@gmail.com', 'admin@elnour.com'));

-- سياسة 3: السماح للعميل المسجل باستعراض وتتبع طلباته الشخصية فقط
CREATE POLICY "Users view own bookings" ON public.bookings
    FOR SELECT USING (auth.uid() = user_id);
