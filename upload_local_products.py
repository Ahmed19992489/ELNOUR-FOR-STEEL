import os
import re
import urllib.request
import json
import ssl
import sys

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
    print("Starting product image upload automation script...")
    print("============================================================")
    
    # 1. Login with Admin credentials from sys.argv or input
    if len(sys.argv) > 2:
        email = sys.argv[1].strip()
        password = sys.argv[2].strip()
    else:
        email = input("Enter admin email: ").strip()
        password = input("Enter admin password: ").strip()
    
    print("\n[AUTH] Logging in and fetching access token...")
    login_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    login_payload = {"email": email, "password": password}
    
    res, err = make_request(login_url, method="POST", data=login_payload)
    if err:
        print(f"[ERROR] Login failed: {err}")
        return
        
    access_token = res.get("access_token")
    if not access_token:
        print("[ERROR] Access token not found in response.")
        return
    print("[SUCCESS] Logged in successfully.")
    
    auth_headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    # 2. Create the "New Paintings" category
    print("\n[CATEGORY] Ensuring category 'New Paintings' exists...")
    cat_url = f"{SUPABASE_URL}/rest/v1/categories"
    cat_payload = {"name": "لوحات جديدة", "sort_order": 6}
    
    _, err = make_request(cat_url, method="POST", headers=auth_headers, data=cat_payload)
    if err:
        print("[INFO] New paintings category already exists.")
    else:
        print("[SUCCESS] New paintings category created.")
        
    # 3. Scan workspace for downloaded Facebook images
    print("\n[SCAN] Scanning project folder for downloaded Facebook images...")
    img_pattern = re.compile(r"^\d+_\d+_\d+_n\.jpg$")
    files = [f for f in os.listdir(WORKSPACE_DIR) if img_pattern.match(f)]
    
    if not files:
        print("[INFO] No new downloaded Facebook images found (pattern: numbers_n.jpg).")
        return
        
    print(f"[FOUND] Found {len(files)} new images ready for upload.")
    
    success_count = 0
    for idx, filename in enumerate(files):
        file_path = os.path.join(WORKSPACE_DIR, filename)
        print(f"\n[{idx+1}/{len(files)}] Processing image: {filename}")
        
        # A. Upload Image to Supabase Storage
        upload_url = f"{SUPABASE_URL}/storage/v1/object/products-images/{filename}"
        with open(file_path, "rb") as img_file:
            img_bytes = img_file.read()
            
        upload_headers = auth_headers.copy()
        upload_headers["Content-Type"] = "image/jpeg"
        
        _, upload_err = make_request(upload_url, method="POST", headers=upload_headers, data=img_bytes)
        if upload_err:
            print(f"[WARNING] Image upload warning (might be already uploaded): {upload_err}")
            
        # B. Insert Product into database
        prod_payload = {
            "title": f"لوحة معدنية راقية #{filename.split('_')[0]}",
            "category": "لوحات جديدة",
            "price": 3600,
            "original_price": 5600,
            "specifications": "حديد 2.5 مم | أسود مطفي فاخر",
            "sizes": "100\u00d7100 سم:3600 | 80\u00d780 سم:3000",
            "image_url": f"products-images/{filename}",
            "description": "لوحة جدارية فاخرة مقطوعة بالليزر بدقة متناهية ومطلية بدهان حراري مقاوم للرطوبة والصدأ."
        }
        
        # Check if product with this image already exists to avoid duplicates
        prod_url = f"{SUPABASE_URL}/rest/v1/products"
        check_url = f"{SUPABASE_URL}/rest/v1/products?image_url=eq.products-images/{filename}"
        check_res, _ = make_request(check_url, method="GET", headers=auth_headers)
        if check_res and len(check_res) > 0:
            print(f"[INFO] Product for this image already exists in database.")
            continue
            
        _, insert_err = make_request(prod_url, method="POST", headers=auth_headers, data=prod_payload)
        if insert_err:
            print(f"[ERROR] Failed to insert product in database: {insert_err}")
        else:
            print(f"[SUCCESS] Image uploaded and product inserted successfully.")
            success_count += 1
            
    print("\n============================================================")
    print(f"[DONE] Automation task complete! Uploaded and added {success_count} new metal art products.")
    print("TIP: You can now log into the admin panel to customize their titles, categories, and prices.")
    print("============================================================")

if __name__ == "__main__":
    main()
