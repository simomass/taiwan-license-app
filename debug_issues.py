import json

with open('assets/questions.json', encoding='utf-8') as f:
    qs = json.load(f)

# Verify Issue 1: No more bad fallback images
print("=== FALLBACK IMAGE CHECK ===")
fallback = [q for q in qs if '_fallback.png' in q.get('image_path', '')]
sign_qs = [q for q in fallback if q['question'] == "What does this sign/image indicate?"]
text_qs = [q for q in fallback if q['question'] != "What does this sign/image indicate?"]
print(f"Total fallback images: {len(fallback)}")
print(f"  Sign questions (correct): {len(sign_qs)}")
print(f"  Text questions (BAD): {len(text_qs)}")
if text_qs:
    for q in text_qs[:5]:
        print(f"    BAD: {q['id']}: {q['question'][:60]}...")

# Verify Issue 2: Long T/F questions fixed
print("\n=== LONG T/F QUESTIONS CHECK ===")
long_tf = [q for q in qs if len(q['question']) > 300 and q['options'] == ['O (True)', 'X (False)']]
print(f"T/F questions over 300 chars: {len(long_tf)}")
for q in long_tf[:5]:
    print(f"  {q['id']}: {len(q['question'])} chars - {q['question'][:80]}...")

# Check the specific mountain road question
print("\n=== SPECIFIC QUESTION CHECKS ===")
q655 = next((q for q in qs if q['id'] == 'pdf_3_655'), None)
if q655:
    print(f"pdf_3_655: {len(q655['question'])} chars")
    print(f"  Text: {q655['question']}")

# Check the screenshot questions
print()
for q in qs:
    if q['id'] == 'pdf_1_5':
        print(f"Weight limit (pdf_1_5): img='{q.get('image_path','')}'")
    if q['id'] == 'pdf_1_535':
        print(f"Red light (pdf_1_535): img='{q.get('image_path','')}'")
    if q['id'] == 'pdf_1_561':
        print(f"Fire trucks (pdf_1_561): img='{q.get('image_path','')}'")

# Check T/F with leaked O/X that were fixed
print("\n=== PREVIOUSLY LEAKED T/F QUESTIONS ===")
for qid in ['pdf_3_12', 'pdf_3_52', 'pdf_3_194', 'pdf_3_324']:
    q = next((q for q in qs if q['id'] == qid), None)
    if q:
        has_ox = ' O ' in q['question'] or ' X ' in q['question']
        print(f"  {q['id']}: {len(q['question'])} chars, still_has_OX={has_ox}")
