import os
import re
import urllib.request
import json
import ssl

# ============================================================
# CONFIGURATION
# ============================================================
SUPABASE_URL = "https://tsdkhsgkqwaewfgldquj.supabase.co"
ANON_KEY = "sb_publishable_N028vRa3HBpSMPFTdLxoOA_SOZiwMZy"
WORKSPACE_DIR = r"c:\Users\pc2\Downloads\النور للحديد"

# ============================================================
# HELPER FOR HTTP REQUESTS USING URLLIB
# ============================================================
def make_request(url, method="GET", headers=None, data=None):
    if headers is None:
        headers = {}
    headers["apikey"] = ANON_KEY
    
    # Disable SSL verification issues if any
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    req_data = None
    if data is not None:
        if isinstance(data, (dict, list)):
            req_data = json.dumps(data).encode("utf-8")
            headers["Content-Type"] = "application/json"
        else:
            req_data = data  # binary data for uploads
            
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            res_data = response.read()
            if response.status in (200, 201):
                try:
                    return json.loads(res_data.decode("utf-8")), None
                except:
                    return res_data.decode("utf-8"), None
            return None, f"Status: {response.status}"
    except urllib.error.HTTPError as e:
        try:
            err_msg = e.read().decode("utf-8")
            return None, f"HTTP Error {e.code}: {err_msg}"
        except:
            return None, f"HTTP Error {e.code}"
    except Exception as e:
        return None, str(e)

# ============================================================
# MAIN AUTOMATION FLOW
# ============================================================
def main():
    print("============================================================")
    print("🚀 سكريبت أتمتة رفع صور المنتجات لـ Supabase - النور للحديد")
    print("============================================================")
    
    # 1. Login with Admin credentials
    email = input("أدخل بريد الأدمن الإلكتروني (Supabase Auth): ").strip()
    password = input("أدخل كلمة المرور: ").strip()
    
    print("\n🔑 جاري تسجيل الدخول والحصول على رمز الوصول...")
    login_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    login_payload = {"email": email, "password": password}
    
    res, err = make_request(login_url, method="POST", data=login_payload)
    if err:
        print(f"❌ فشل تسجيل الدخول: {err}")
        return
        
    access_token = res.get("access_token")
    if not access_token:
        print("❌ لم يتم العثور على رمز الوصول في الاستجابة.")
        return
    print("✅ تم تسجيل الدخول بنجاح.")
    
    auth_headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    # 2. Create the "لوحات جديدة" category
    print("\n🏷️ جاري إنشاء قسم 'لوحات جديدة'...")
    cat_url = f"{SUPABASE_URL}/rest/v1/categories"
    cat_payload = {"name": "لوحات جديدة", "sort_order": 6}
    
    # We use PUT or POST with On Conflict to avoid duplicate key error
    # but we can try POST, if it fails because it exists, it's fine
    _, err = make_request(cat_url, method="POST", headers=auth_headers, data=cat_payload)
    if err:
        print("ℹ️ قسم 'لوحات جديدة' موجود بالفعل أو تم إنشاؤه مسبقاً.")
    else:
        print("✅ تم إنشاء قسم 'لوحات جديدة' بنجاح.")
        
    # 3. Scan workspace for downloaded Facebook images
    print("\n📂 جاري فحص مجلد المشروع بحثاً عن صور جديدة...")
    img_pattern = re.compile(r"^\d+_\d+_\d+_n\.jpg$")
    files = [f for f in os.listdir(WORKSPACE_DIR) if img_pattern.match(f)]
    
    if not files:
        print("ℹ️ لم يتم العثور على صور جديدة بنمط أسماء فيسبوك (أرقام_n.jpg) في مجلد المشروع.")
        return
        
    print(f"📋 تم العثور على {len(files)} صورة جديدة جاهزة للرفع.")
    
    success_count = 0
    for idx, filename in enumerate(files):
        file_path = os.path.join(WORKSPACE_DIR, filename)
        print(f"\n[{idx+1}/{len(files)}] جاري معالجة الصورة: {filename}")
        
        # A. Upload Image to Supabase Storage
        upload_url = f"{SUPABASE_URL}/storage/v1/object/products-images/{filename}"
        with open(file_path, "rb") as img_file:
            img_bytes = img_file.read()
            
        upload_headers = auth_headers.copy()
        upload_headers["Content-Type"] = "image/jpeg"
        
        # Check if already uploaded
        # Upload using POST
        _, upload_err = make_request(upload_url, method="POST", headers=upload_headers, data=img_bytes)
        if upload_err:
            print(f"⚠️ تنبيه أثناء رفع الصورة (قد تكون مرفوعة بالفعل): {upload_err}")
            
        # B. Insert Product into database
        prod_url = f"{SUPABASE_URL}/rest/v1/products"
        prod_payload = {
            "title": f"لوحة معدنية ليزر راقية #{filename.split('_')[0]}",
            "category": "لوحات جديدة",
            "price": 3600,
            "original_price": 5600,
            "specifications": "حديد 2.5 مم | أسود مطفي فاخر",
            "sizes": "100×100 سم:3600 | 80×80 سم:3000",
            "image_url": f"products-images/{filename}",
            "description": "لوحة جدارية فاخرة مقطوعة بالليزر بدقة متناهية ومطلية بدهان حراري مقاوم للرطوبة والصدأ."
        }
        
        # Check if product with this image already exists to avoid duplicates
        check_url = f"{SUPABASE_URL}/rest/v1/products?image_url=eq.products-images/{filename}"
        check_res, _ = make_request(check_url, method="GET", headers=auth_headers)
        if check_res and len(check_res) > 0:
            print(f"ℹ️ المنتج الخاص بهذه الصورة موجود بالفعل في قاعدة البيانات.")
            continue
            
        _, insert_err = make_request(prod_url, method="POST", headers=auth_headers, data=prod_payload)
        if insert_err:
            print(f"❌ فشل إضافة المنتج في قاعدة البيانات: {insert_err}")
        else:
            print(f"✅ تم رفع الصورة وإدراج المنتج بنجاح.")
            success_count += 1
            
    print("\n============================================================")
    print(f"🎉 انتهت المهمة بنجاح! تم رفع وإضافة {success_count} لوحة جديدة للمعرض.")
    print("💡 يمكنك الآن الدخول للوحة الأدمن وتعديل تصنيفاتهم وأسمائهم بسهولة.")
    print("============================================================")

if __name__ == "__main__":
    main()
