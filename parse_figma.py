import json
import os
import urllib.request
import urllib.error

# Load figma json
figma_file_path = "figma_file.json"
token = "figd_W04RTaOnxy2Oky2JhOU09Kebq-IFGnO5_8-ACPZZ"
file_key = "nxsa7j2xQLxJEqZ1hx7z6u"

if not os.path.exists(figma_file_path):
    print(f"Error: {figma_file_path} not found.")
    exit(1)

with open(figma_file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# Traverse document to find top-level frames on the first canvas/page
frames = []

def find_frames(node, page_name=""):
    if node.get("type") == "CANVAS":
        page_name = node.get("name")
        for child in node.get("children", []):
            find_frames(child, page_name)
    elif node.get("type") in ["FRAME", "COMPONENT", "INSTANCE"]:
        # Only top-level frames on a canvas
        frames.append({
            "id": node.get("id"),
            "name": node.get("name"),
            "page": page_name,
            "width": node.get("absoluteBoundingBox", {}).get("width", 0),
            "height": node.get("absoluteBoundingBox", {}).get("height", 0)
        })
    else:
        # If it's a group, we can inspect its children
        if node.get("type") == "GROUP":
            for child in node.get("children", []):
                find_frames(child, page_name)

document = data.get("document", {})
for child in document.get("children", []):
    find_frames(child)

print(f"Found {len(frames)} frames/components in Figma file:")
for f in frames:
    print(f" - ID: {f['id']} | Name: {f['name']} | Page: {f['page']} ({f['width']}x{f['height']})")

# Let's request the images for these frames from Figma
os.makedirs("design", exist_ok=True)
node_ids = ",".join([f["id"] for f in frames])

images_url = f"https://api.figma.com/v1/images/{file_key}?ids={node_ids}&format=png&scale=2"
req = urllib.request.Request(images_url)
req.add_header("X-Figma-Token", token)

try:
    print("\nRequesting frame images from Figma REST API...")
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        images = res_data.get("images", {})
        
        for f in frames:
            node_id = f["id"]
            img_url = images.get(node_id)
            if img_url:
                sanitized_name = "".join([c if c.isalnum() or c in " _-" else "_" for c in f["name"]])
                output_path = os.path.join("design", f"{sanitized_name}.png")
                print(f"Downloading {f['name']} -> {output_path}...")
                
                # Fetch the image bytes
                img_req = urllib.request.Request(img_url)
                with urllib.request.urlopen(img_req) as img_resp:
                    with open(output_path, "wb") as img_file:
                        img_file.write(img_resp.read())
            else:
                print(f"No image URL returned for frame: {f['name']} (ID: {node_id})")
                
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code} - {e.reason}")
    print(e.read().decode("utf-8"))
except Exception as e:
    print(f"General Error: {e}")
