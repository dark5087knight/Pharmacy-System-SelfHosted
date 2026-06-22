import os
import re

lib_dir = "d:/LAB/Pharmacy SelfHosted/flutter_pharmacy/lib"

def restore():
    # Match any brace { not preceded by a dollar sign $ that contains a .toIQD() call
    pattern = r'(?<!\$)\{([^{}]+?\.toIQD\(\)\})'
    
    count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"):
                continue
            path = os.path.join(root, file)
            
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                
            original = content
            content = re.sub(pattern, r'${\1', content)
            
            if content != original:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Restored interpolations in: {file}")
                count += 1
                
    print(f"Restoration completed. Updated {count} files.")

if __name__ == "__main__":
    restore()
