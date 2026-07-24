import json

qs = json.load(open('assets/questions.json'))

print("=== Remaining fallback option questions ===")
for q in qs:
    if 'Option 1' in q.get('options', []):
        print(f"  {q['id']}: q={q['question'][:80]}")
        print(f"    options={q['options']}")
        print(f"    img={q.get('image_path','')}")
        print()

print("=== Previously broken questions (should be fixed now) ===")
for qid in ['pdf_1_117', 'pdf_1_424', 'pdf_1_551', 'pdf_1_792', 'pdf_4_529']:
    q = next((q for q in qs if q['id'] == qid), None)
    if q:
        print(f"  {q['id']}:")
        print(f"    question: {q['question'][:100]}")
        print(f"    options: {q['options']}")
        print(f"    image: {q.get('image_path','')}")
        print(f"    correct: {q['correct_index']}")
        print()

print("=== Regression check: total counts ===")
total = len(qs)
with_img = sum(1 for q in qs if q.get('image_path'))
sign_qs = sum(1 for q in qs if q['question'] == 'What does this sign/image indicate?')
empty_q = sum(1 for q in qs if not q['question'])
fallback = sum(1 for q in qs if 'Option 1' in q.get('options', []))
print(f"  Total: {total}")
print(f"  With images: {with_img}")
print(f"  Sign questions: {sign_qs}")
print(f"  Empty questions: {empty_q}")
print(f"  Fallback options: {fallback}")
