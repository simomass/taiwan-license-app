import json
qs = json.load(open("/mnt/c/Users/ASUS/app_patente_taiwanese/assets/questions.json"))
print(next((q for q in qs if q["id"] == "pdf_1_712"), None))
print(next((q for q in qs if q["id"] == "pdf_6_18"), None))
