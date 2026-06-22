import os
import re

lib_dir = "d:/LAB/Pharmacy SelfHosted/flutter_pharmacy/lib"

def fix():
    # Pattern to match single-quoted or double-quoted string interpolations containing only a .toIQD() call
    pattern_single = r"'\$\{([^{}]+?\.toIQD\(\))\}'"
    pattern_double = r'"\$\{([^{}]+?\.toIQD\(\))\}"'
    
    count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"):
                continue
            path = os.path.join(root, file)
            
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                
            original = content
            content = re.sub(pattern_single, r'\1', content)
            content = re.sub(pattern_double, r'\1', content)
            
            if content != original:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Fixed interpolations in: {file}")
                count += 1
                
    print(f"Interpolation fixing completed. Updated {count} files.")

if __name__ == "__main__":
    fix()
