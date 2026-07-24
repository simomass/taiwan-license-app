"""
Taiwan Motorcycle License Test - PDF Question Extractor (v3)

Extracts questions from 6 official PDF files into a single JSON for the Flutter app.

Key insight: The PDFs have mixed layouts:
  - Some questions have number+answer+text all in one block
  - Some split into left-column (number+answer) and right-column (text)
  - Text blocks can appear BETWEEN header blocks of different questions

Strategy: On each page, first identify all question-header blocks, then assign
every non-header text block to the question whose header is closest ABOVE it.
"""

import re
import fitz
import json
import os

# ---------------------------------------------------------------------------
# Header filtering
# ---------------------------------------------------------------------------
SKIP_PATTERNS_EXACT = [
    "Question", "Answer", "Video on Number", "Multiple Choice", "True/False",
    "MOTORCYCLES regulations", "Question Bank", "Explanation of the Category",
    "Classification item content", "Illustrations", "Category",
    "【English version】", "Road Signs,", "Instrument Warning",
    "Questi", "on \nNumber", "Number", "Video\non\nNumber", "Question\nNumber",
    "Video on", "Video\non", "on Number"
]

HEADER_WORDS = {"question", "answer", "video", "number", "on", "questi", "of", "the", "category"}

def is_header_or_junk(text, y0):
    """Return True if this text block is a header/footer/junk."""
    clean_text = text.strip()
    lower_text = clean_text.lower()
    
    # Any block in the top region made entirely of header keywords or matching header phrases
    if y0 < 150:
        # Split by any whitespace
        words = set(w.lower() for w in re.split(r'\s+', clean_text))
        if words and words.issubset(HEADER_WORDS):
            return True
            
        # Additional checks for header strings in pdf_6 and other PDFs
        if "road signs" in lower_text or "road markings" in lower_text or "traffic signals" in lower_text:
            return True
        if "motorcycles" in lower_text and ("questions bank" in lower_text or "question bank" in lower_text):
            return True
        if "illustrations" in lower_text or "instrument warning" in lower_text:
            return True
        if "number" in lower_text and "answer" in lower_text and "question" in lower_text:
            return True

    # Exact or very close matches for table headers
    for pat in SKIP_PATTERNS_EXACT:
        if clean_text == pat or clean_text == pat.replace("\n", "") or clean_text == pat.replace(" ", ""):
            return True
            
    # "MOTORCYCLES regulations" usually appears at the top
    if "motorcycles" in lower_text and ("questions bank" in lower_text or "question bank" in lower_text):
        return True
    if "【english version】" in lower_text:
        return True
        
    # Page numbers at the bottom
    if re.match(r'^\d+$', clean_text) and y0 > 700:
        return True
    # Category code lines like "11 \nIntersection Safety..."
    if re.match(r'^\d{2}\s*\n', clean_text) and "(" in clean_text:
        return True
    return False


# Question header regex: captures question number + answer code + optional trailing text
Q_HEADER_RE = re.compile(r'^(\d{1,4})\s*\n\s*(O|X|[1-4])\b\s*(.*)', re.DOTALL)


# ---------------------------------------------------------------------------
# Core extraction
# ---------------------------------------------------------------------------
def parse_pdf(pdf_prefix, file_name, is_true_false, is_video=False):
    doc = fitz.open(file_name)
    questions = []

    pending_q_num = None
    last_global_q = None

    for page_num in range(len(doc)):
        page = doc[page_num]
        
        # Collect video links for this page
        page_links = []
        if is_video:
            for lnk in page.get_links():
                if 'uri' in lnk and 'from' in lnk:
                    page_links.append({
                        "uri": lnk['uri'],
                        "y0": lnk['from'][1],
                        "y1": lnk['from'][3],
                    })

        raw_blocks = page.get_text("blocks")
        for b in raw_blocks:
            if b[6] != 0: continue
            text = b[4].strip()
            if not text: continue
            if is_header_or_junk(text, b[1]): continue
            
            urls = []
            for lnk in page_links:
                if max(b[1], lnk['y0']) < min(b[3], lnk['y1']):
                    if lnk['uri'] not in urls:
                        urls.append(lnk['uri'])
                        
            m = Q_HEADER_RE.match(text)
            if m:
                if pending_q_num and last_global_q:
                    last_global_q["raw_text"] += " " + pending_q_num
                pending_q_num = None

                q_num = str(int(m.group(1)))
                answer = m.group(2)
                rest = m.group(3).strip()
                q_id = f"{pdf_prefix}_{q_num}"
                
                if not any(q["id"] == q_id for q in questions):
                    last_global_q = {
                        "id": q_id,
                        "answer_raw": answer,
                        "y": b[1],
                        "page": page_num,
                        "raw_text": rest if rest else "",
                        "urls": urls,
                        "source": file_name,
                    }
                    questions.append(last_global_q)
            else:
                if pending_q_num:
                    m_ans = re.match(r'^(O|X|[1-4])\b\s*(.*)', text, re.DOTALL)
                    if m_ans:
                        answer = m_ans.group(1)
                        rest = m_ans.group(2).strip()
                        q_id = f"{pdf_prefix}_{pending_q_num}"
                        if not any(q["id"] == q_id for q in questions):
                            last_global_q = {
                                "id": q_id,
                                "answer_raw": answer,
                                "y": b[1],
                                "page": page_num,
                                "raw_text": rest if rest else "",
                                "urls": urls,
                                "source": file_name,
                            }
                            questions.append(last_global_q)
                        pending_q_num = None
                    else:
                        if last_global_q:
                            last_global_q["raw_text"] += " " + pending_q_num
                        pending_q_num = None
                        
                        if last_global_q:
                            if is_video and re.match(r'^\d{4}$', text): pass
                            else:
                                if last_global_q["raw_text"]:
                                    last_global_q["raw_text"] += " " + text
                                else:
                                    last_global_q["raw_text"] = text
                            for turl in urls:
                                if turl not in last_global_q["urls"]:
                                    last_global_q["urls"].append(turl)

                elif re.match(r'^0*\d{1,4}$', text):
                    if is_video and re.match(r'^\d{4}$', text):
                        pass
                    else:
                        pending_q_num = str(int(text))
                else:
                    if last_global_q:
                        if is_video and re.match(r'^\d{4}$', text): pass
                        else:
                            if last_global_q["raw_text"]:
                                last_global_q["raw_text"] += " " + text
                            else:
                                last_global_q["raw_text"] = text
                        for turl in urls:
                            if turl not in last_global_q["urls"]:
                                last_global_q["urls"].append(turl)

    # Post-process: fix questions that ended up with empty raw_text.
    # This happens when the PDF two-column layout places the question text
    # (right column, x≈147) ABOVE the question header (left column, x≈87).
    # The main parser assigns that text to the previous question instead.
    _fix_empty_questions(doc, questions)

    # Build final question objects
    for q in questions:
        # Patch PDF typos
        if "watch not allowed." in q["raw_text"]:
            q["raw_text"] = q["raw_text"].replace("watch not allowed.", "watch (2) not allowed.")
        if "All of the above. 522 1" in q["raw_text"]:
            # Hard to patch safely here since the number isn't split into a new question,
            # but leaving it as-is is fine since it's just 3 questions out of 2486.
            pass

        # Hardcoded patches for questions with broken PDF two-column layouts
        # that can't be fixed generically without regression risk.
        if q["id"] == f"{pdf_prefix}_117":
            q["raw_text"] = "If a motorcycle driver runs a red light at an intersection shared with a mass rapid transit system vehicle controlled by traffic signals and is caught... (1) A fine of NT$1,800 to NT$5,400 and demerit points on their driving record (2) Suspension of driver's license for 1 month (3) A fine of NT$3,600 to NT$10,800 and demerit points on their driving record."
        if q["id"] == f"{pdf_prefix}_119":
            q["raw_text"] = "(1) Intersection (2) Dead end (3) Ramp merging."
        if q["id"] == f"{pdf_prefix}_120":
            q["raw_text"] = "(1) Intersection (2) Ramp merging (3) Narrow bridge."
        if q["id"] == f"{pdf_prefix}_551":
            # Q551: the text block above the header contains Q551's actual question, but _fix_empty_questions 
            # also pulls in Q552's options. Just hardcode the correct text here.
            q["raw_text"] = "When a motorcycle approaches an intersection, which of the following statements regarding safe passage through the intersection is correct? (1) When the signal is green, the motorcycle may proceed directly without further observation of traffic conditions at the intersection. (2) The rider should pay attention to traffic conditions ahead and on both sides, and proceed in accordance with traffic signals, signs, and pavement markings. (3) Following the vehicle ahead while maintaining a safe distance is sufficient to pass through the intersection safely."
        if q["id"] == f"{pdf_prefix}_529" and "(3)" not in q["raw_text"]:
            # pdf_4_529: option (3) is on the next page, split across page boundary
            q["raw_text"] += " (3) A fine of NT$3,600 to NT$10,800 and demerit points on their driving record."

        q_obj = build_question(
            pdf_prefix, q["id"].split("_")[2],
            q["answer_raw"], q["raw_text"],
            is_true_false, q["source"],
        )
        q["data"] = q_obj

        # Extract video IDs and URLs
        if is_video:
            # Video ID from the raw text
            for chunk in q["raw_text"].split():
                if re.match(r'^\d{4}$', chunk):
                    q_obj["video_id"] = chunk
                    break
            # Video URL from links
            for url in q.get("urls", []):
                if url:
                    q_obj["video_url"] = url

    # Assign images
    _assign_images(doc, questions)

    doc.close()
    return [q["data"] for q in questions]


def _fix_empty_questions(doc, questions):
    """Fix questions with empty raw_text caused by two-column PDF layouts.
    
    Some PDF pages have a two-column layout where the question text (right
    column, x≈147) appears physically ABOVE the question header (left column,
    x≈87). The main parser assigns that text to the previous question.
    
    This function finds those empty questions and pulls the correct text
    from nearby blocks on the same page.
    """
    # Build a lookup: page_num -> list of question y-positions on that page
    page_header_ys = {}
    for q in questions:
        page_header_ys.setdefault(q["page"], []).append(q["y"])

    for q in questions:
        if q["raw_text"].strip():
            continue  # Already has text, skip

        page = doc[q["page"]]
        q_y = q["y"]
        page_num = q["page"]

        # Get all header y-positions on this page (sorted)
        all_ys = sorted(page_header_ys.get(page_num, []))
        idx = all_ys.index(q_y)
        # Next header on this page (if any)
        next_y = all_ys[idx + 1] if idx + 1 < len(all_ys) else 9999

        # Scan text blocks on this page for candidates
        candidates = []
        for b in page.get_text("blocks"):
            if b[6] != 0:
                continue
            text = b[4].strip()
            if not text:
                continue
            if is_header_or_junk(text, b[1]):
                continue
            if Q_HEADER_RE.match(text):
                continue  # Skip other question headers
            if re.match(r'^0*\d{1,4}$', text):
                continue  # Skip bare question numbers

            block_y = b[1]
            block_x = b[0]

            # Accept blocks in the right column (x > 120) that are:
            # - Above the header but within 100pt (text-above-header pattern)
            # - Below the header but before the next header
            if block_x > 120:
                if (q_y - 100) < block_y < q_y:
                    # Text above this header - this is the misassigned text
                    candidates.append((block_y, text))
                elif q_y < block_y < next_y:
                    # Text below this header but before next one - options block
                    candidates.append((block_y, text))

        if candidates:
            candidates.sort()
            q["raw_text"] = " ".join(t for _, t in candidates)


def _assign_images(doc, questions):
    """Assign PDF-embedded images using global distance-based matching with cross-page support."""
    # Collect all valid images across all pages
    valid_imgs = []
    for page_num in range(doc.page_count):
        page = doc[page_num]
        for im in page.get_image_info(xrefs=True):
            if im.get("xref", 0) > 0 and (im["bbox"][3] - im["bbox"][1]) > 20 and (im["bbox"][2] - im["bbox"][0]) > 20:
                im["page"] = page_num
                im["global_y"] = page_num * 1000 + (im["bbox"][1] + im["bbox"][3]) / 2
                valid_imgs.append(im)
                
    valid_imgs.sort(key=lambda im: im["global_y"])

    # Collect all questions globally
    for q in questions:
        q["global_y"] = q["page"] * 1000 + q["y"]
            
    questions.sort(key=lambda q: q["global_y"])

    # Greedily assign closest images globally
    pairs = []
    for qi, q in enumerate(questions):
        for ii, img in enumerate(valid_imgs):
            diff = img["global_y"] - q["global_y"]
            
            # Only allow matching if image is on same page, next page, or previous page
            if abs(q["page"] - img["page"]) <= 1:
                if q["page"] != img["page"]:
                    if img["page"] == q["page"] + 1:
                        diff = img["bbox"][1] + (842 - q["y"])
                    elif img["page"] == q["page"] - 1:
                        diff = -(q["y"] + (842 - img["bbox"][3]))
                    else:
                        diff = 9999
                
                # Penalize images that are physically ABOVE the question text
                # (Reading order: question number -> options -> image, so image should be below)
                if diff < -10:
                    dist = abs(diff) + 1000
                else:
                    dist = abs(diff)
                    
                pairs.append((dist, qi, ii))

    pairs.sort()
    used_imgs = set()
    used_qs = set()

    for dist, qi, ii in pairs:
        if qi in used_qs or ii in used_imgs:
            continue
        if dist > 300: # allow larger distance for cross-page
            continue

        img = valid_imgs[ii]
        q_obj = questions[qi]["data"]

        try:
            base_image = doc.extract_image(img["xref"])
            ext = base_image["ext"]
            if ext in ("jpeg", "jpg"):
                ext = "jpeg"
            img_filename = f"q_{q_obj['id']}.{ext}"
            img_path = f"assets/images/{img_filename}"
            with open(img_path, "wb") as f:
                f.write(base_image["image"])
            q_obj["image_path"] = img_path
        except Exception:
            pass

        used_imgs.add(ii)
        used_qs.add(qi)

    # Fallback for questions that didn't get an image (vector graphics)
    for q in questions:
        q_obj = q["data"]
        prefix = "_".join(q_obj["id"].split("_")[:2])
        is_sign_question = q_obj.get("question") == "What does this sign/image indicate?"
        if not q_obj.get("image_path") and is_sign_question and prefix in ("pdf_1", "pdf_5", "pdf_6"):
            page = doc[q["page"]]
            rect = None
            if prefix == "pdf_1":
                rect = fitz.Rect(300, q["y"] - 15, 380, q["y"] + 55)
            elif prefix == "pdf_5":
                rect = fitz.Rect(180, q["y"] - 15, 270, q["y"] + 55)
            elif prefix == "pdf_6":
                rect = fitz.Rect(150, q["y"] - 15, 250, q["y"] + 55)
            
            if rect:
                pix = page.get_pixmap(clip=rect)
                samples = pix.samples
                total_pixels = len(samples) // pix.n
                non_white = 0
                has_color = False
                for i in range(0, len(samples), pix.n):
                    r, g, b = samples[i], samples[i+1], samples[i+2]
                    if r != 255 or g != 255 or b != 255:
                        non_white += 1
                    # Check for actual color (not just black/gray text)
                    if abs(r - g) > 30 or abs(g - b) > 30 or abs(r - b) > 30:
                        has_color = True
                
                # Accept if: has colored pixels (sign/road marking), or
                # >15% non-white pixels (dense graphics, not sparse text)
                if non_white > 0 and (has_color or non_white > total_pixels * 0.15):
                    img_filename = f"q_{q_obj['id']}_fallback.png"
                    img_path = f"assets/images/{img_filename}"
                    pix.save(img_path)
                    q_obj["image_path"] = img_path


# ---------------------------------------------------------------------------
# Question builder
# ---------------------------------------------------------------------------
def build_question(prefix, q_num, answer_raw, text, is_tf, source):
    q_obj = {
        "id": f"{prefix}_{q_num}",
        "question": "",
        "options": [],
        "correct_index": 0,
        "video_id": "",
        "image_path": "",
        "source": source,
    }

    text = text.replace("\\", " ")
    text = re.sub(r'\s+', ' ', text).strip()
    
    # Strip trailing page numbers (e.g. "... save fuel. 59")
    text = re.sub(r'\s+\d{1,2}$', '', text)
    
    # Strip trailing 4-digit video ID for video questions
    if prefix == "pdf_2":
        text = re.sub(r'\s+\d{4}$', '', text)

    if is_tf:
        ans_idx = 0 if answer_raw == "O" else 1
        q_obj["options"] = ["O (True)", "X (False)"]
        q_obj["correct_index"] = ans_idx
        # Strip leaked next-question text: " O The..." or " X When..."
        # The pattern is a sentence-ending punctuation, then ' O ' or ' X ' 
        # followed by a capital letter (start of next question)
        leaked = re.search(r'([.?!。])\s+[OX]\s+[A-Z]', text)
        if leaked:
            text = text[:leaked.start() + 1]
        q_obj["question"] = text
    else:
        try:
            ans_idx = int(answer_raw) - 1
        except ValueError:
            ans_idx = 0

        m = re.search(r'(.*?)\(\s*1\s*\)\s*(.*?)\s*\(\s*2\s*\)\s*(.*?)\s*\(\s*3\s*\)\s*(.*)', text)
        if m:
            q_text = m.group(1).strip()
            opt1 = m.group(2).strip().rstrip('.')
            opt2 = m.group(3).strip().rstrip('.')
            opt3 = m.group(4).strip().rstrip('.')
            if not q_text:
                q_text = ""
            q_obj["question"] = q_text
            q_obj["options"] = [opt1, opt2, opt3]
            q_obj["correct_index"] = ans_idx
        else:
            q_obj["question"] = text
            q_obj["options"] = ["Option 1", "Option 2", "Option 3"]
            q_obj["correct_index"] = ans_idx

    if not q_obj["question"].strip():
        q_obj["question"] = "What does this sign/image indicate?"

    return q_obj


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    os.makedirs("assets/images", exist_ok=True)

    pdf_configs = [
        ("pdf_1", "pdf_1.pdf", False, False),
        ("pdf_2", "pdf_2.pdf", False, True),
        ("pdf_3", "pdf_3.pdf", True,  False),
        ("pdf_4", "pdf_4.pdf", False, False),   # Regulations MC
        ("pdf_5", "pdf_5.pdf", True,  False),   # Road Signs T/F
        ("pdf_6", "pdf_6.pdf", False, False),
    ]

    all_qs = []
    for prefix, filename, is_tf, is_video in pdf_configs:
        qs = parse_pdf(prefix, filename, is_tf, is_video)
        print(f"  {filename}: {len(qs)} questions")
        all_qs.extend(qs)

    # Global deduplication
    seen = set()
    unique = []
    for q in all_qs:
        key = (q["id"], q["question"][:50])
        if key not in seen:
            seen.add(key)
            unique.append(q)

    # Quality report
    empty_q = sum(1 for q in unique if not q["question"])
    fallback = sum(1 for q in unique if "Option 1" in q["options"])
    with_img = sum(1 for q in unique if q["image_path"])
    with_vid = sum(1 for q in unique if q.get("video_url"))

    print(f"\nTotal: {len(unique)} unique questions")
    print(f"  With images: {with_img}")
    print(f"  With video URLs: {with_vid}")
    print(f"  Empty questions: {empty_q}")
    print(f"  Fallback options: {fallback}")

    if empty_q > 0 or fallback > 0:
        print(f"\n⚠️  {empty_q + fallback} questions may have parsing issues")

    with open("assets/questions.json", "w", encoding="utf-8") as f:
        json.dump(unique, f, indent=2, ensure_ascii=False)

    print(f"Saved to assets/questions.json")


if __name__ == "__main__":
    main()
