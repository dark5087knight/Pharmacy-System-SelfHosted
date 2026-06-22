import os
import re

lib_dir = "d:/LAB/Pharmacy SelfHosted/flutter_pharmacy/lib"

def clean():
    # Match optionally a +/- sign, then any backslashes, then $ and then the interpolation block with .toIQD()
    pattern = r'([+-]?)\\*?\$(\{[^{}]+?\.toIQD\(\)\})'
    
    count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"):
                continue
            path = os.path.join(root, file)
            
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                
            original = content
            content = re.sub(pattern, r'\1\2', content)
            
            if content != original:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Cleaned dollars in: {file}")
                count += 1
                
    print(f"Dollar cleaning completed. Updated {count} files.")

if __name__ == "__main__":
    clean()
