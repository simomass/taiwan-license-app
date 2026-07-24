import fitz

doc = fitz.open("pdf_1.pdf")
page = doc[41]
img_infos = page.get_image_info(xrefs=True)
for i, img in enumerate(img_infos):
    if img.get("xref", 0) > 0:
        base_image = doc.extract_image(img["xref"])
        with open(f"page41_img_{i}.{base_image['ext']}", "wb") as f:
            f.write(base_image["image"])
