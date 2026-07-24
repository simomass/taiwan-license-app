import fitz  # PyMuPDF
import json
import os
import requests
import re
from bs4 import BeautifulSoup

# I URL dei PDF
PDF_PAGE_URL = "https://www.thb.gov.tw/en/News_Download.aspx?n=12579&sms=12831"

def extract_pdfs():
    print(f"Fetching links from {PDF_PAGE_URL}...")
    headers = {"User-Agent": "Mozilla/5.0"}
    response = requests.get(PDF_PAGE_URL, headers=headers)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    
    pdf_links = []
    for a in soup.find_all("a", href=True):
        if "Download.ashx" in a["href"] and ".pdf" in a.text.lower():
            link = "https://www.thb.gov.tw" + a["href"] if a["href"].startswith("/") else a["href"]
            if not link.startswith("http"):
                link = "https://ws.thb.gov.tw/" + link
            name = a.get("title", f"pdf_{len(pdf_links)}")
            pdf_links.append((name, link))
    
    os.makedirs("assets/images", exist_ok=True)
    
    questions_list = []
    
    for name, link in pdf_links:
        print(f"Downloading {name}...")
        try:
            pdf_res = requests.get(link, headers=headers)
            pdf_path = f"{name}.pdf"
            with open(pdf_path, "wb") as f:
                f.write(pdf_res.content)
            
            # Extract questions and images
            qs = parse_pdf(pdf_path)
            questions_list.extend(qs)
            
        except Exception as e:
            print(f"Failed to process {name}: {e}")

    # Salva il JSON
    with open("assets/questions.json", "w", encoding="utf-8") as f:
        json.dump(questions_list, f, indent=4, ensure_ascii=False)
    print("Estrazione completata! File salvati in assets/")

def parse_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    questions = []
    
    # regex for Question Number + Correct Answer: e.g. "424 1"
    q_start_re = re.compile(r"^(\d+)\s+([1-4])$")
    
    current_q = None
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        
        # Estrarre le immagini di questa pagina
        images_info = []
        for img in page.get_image_info():
            bbox = img["bbox"]
            images_info.append({"bbox": bbox, "xref": img["xref"]})
            
        # Extract test blocks
        blocks = page.get_text("blocks")
        # Sort blocks by Y coordinate
        blocks.sort(key=lambda b: b[1])
        
        for b in blocks:
            text = b[4].strip()
            if not text: continue
            
            # Cerca l'inizio di una domanda
            match = q_start_re.match(text)
            if match or (len(text.split('\n')) > 1 and q_start_re.match(text.split('\n')[0].strip())):
                lines = text.split('\n')
                first_line = lines[0].strip()
                m = q_start_re.match(first_line)
                
                # Salva domanda precedente se esiste
                if current_q:
                    finalize_question(current_q, questions)
                    current_q = None
                
                if m:
                    q_id = m.group(1)
                    correct_ans = int(m.group(2)) - 1
                    rest_text = " ".join(lines[1:])
                    current_q = {
                        "id": q_id,
                        "raw_text": rest_text,
                        "correct_index": correct_ans,
                        "video_id": "",
                        "image_path": "",
                        "bbox": b[:4],
                        "page": page_num
                    }
            else:
                if current_q and current_q["page"] == page_num:
                    current_q["raw_text"] += " " + text
                    # estendi la bounding box
                    current_q["bbox"] = (
                        min(current_q["bbox"][0], b[0]),
                        min(current_q["bbox"][1], b[1]),
                        max(current_q["bbox"][2], b[2]),
                        max(current_q["bbox"][3], b[3])
                    )
        
        # Dopo aver processato la pagina, associa le immagini alle domande
        if current_q:
            finalize_question(current_q, questions)
            current_q = None
            
        # Associa le immagini alle domande di questa pagina controllando le coordinate
        page_qs = [q for q in questions if q.get("page") == page_num]
        for img_info in images_info:
            img_y0 = img_info["bbox"][1]
            img_y1 = img_info["bbox"][3]
            img_center = (img_y0 + img_y1) / 2
            
            # Trova la domanda più vicina sulla stessa pagina
            closest_q = None
            min_dist = float('inf')
            for q in page_qs:
                q_y0 = q["bbox"][1]
                q_y1 = q["bbox"][3]
                q_center = (q_y0 + q_y1) / 2
                dist = abs(img_center - q_center)
                if dist < min_dist:
                    min_dist = dist
                    closest_q = q
            
            if closest_q:
                # Salva l'immagine
                try:
                    xref = img_info["xref"]
                    base_image = doc.extract_image(xref)
                    img_ext = base_image["ext"]
                    img_bytes = base_image["image"]
                    img_name = f"assets/images/q_{closest_q['id']}.{img_ext}"
                    with open(img_name, "wb") as f:
                        f.write(img_bytes)
                    closest_q["image_path"] = img_name
                except Exception as e:
                    print(f"Error extracting image for Q {closest_q['id']}: {e}")

    return questions

def finalize_question(q, questions_list):
    text = q["raw_text"]
    # Parse options
    opt_re = re.compile(r"\(1\)(.*?)\(2\)(.*?)\(3\)(.*)")
    m = opt_re.search(text)
    if m:
        question_text = text[:m.start()].strip()
        opts = [m.group(1).strip(), m.group(2).strip(), m.group(3).strip()]
        q["question"] = question_text
        q["options"] = opts
    else:
        # Fallback for True/False questions or other formats
        q["question"] = text
        q["options"] = ["True", "False"] 
        
    # Pulisci per il salvataggio
    if "raw_text" in q: del q["raw_text"]
    if "bbox" in q: del q["bbox"]
    if "page" in q: del q["page"]
    questions_list.append(q)

if __name__ == "__main__":
    extract_pdfs()
