import fitz

doc = fitz.open("pdf_1.pdf")
for i, page in enumerate(doc):
    text = page.get_text()
    if "High-Speed Rail Station" in text:
        print(f"Page {i}")
