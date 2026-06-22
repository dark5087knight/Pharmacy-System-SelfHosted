import os

lib_dir = "d:/LAB/Pharmacy SelfHosted/flutter_pharmacy/lib"

def migrate():
    count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                updated = False
                
                target1 = "import 'package:lucide_icons/lucide_icons.dart';"
                replacement1 = "import 'package:lucide_icons_flutter/lucide_icons.dart';"
                if target1 in content:
                    content = content.replace(target1, replacement1)
                    updated = True
                    
                target2 = 'import "package:lucide_icons/lucide_icons.dart";'
                replacement2 = 'import "package:lucide_icons_flutter/lucide_icons.dart";'
                if target2 in content:
                    content = content.replace(target2, replacement2)
                    updated = True
                
                if updated:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(content)
                    print(f"Updated: {file}")
                    count += 1
    print(f"Migration completed. Updated {count} files.")

if __name__ == "__main__":
    migrate()
