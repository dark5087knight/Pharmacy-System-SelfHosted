import os
import re

lib_dir = "d:/LAB/Pharmacy SelfHosted/flutter_pharmacy/lib"

def migrate():
    # 1. Update lib/theme/theme.dart to add import and extension
    theme_path = os.path.join(lib_dir, "theme", "theme.dart")
    if os.path.exists(theme_path):
        with open(theme_path, "r", encoding="utf-8") as f:
            theme_content = f.read()
        
        # Add import if not present
        if "package:intl/intl.dart" not in theme_content:
            theme_content = "import 'package:intl/intl.dart';\n" + theme_content
            
        # Add extension if not present
        if "extension CurrencyFormatter" not in theme_content:
            # We insert it before the last closing brace or at the end of the file
            theme_content += """

extension CurrencyFormatter on num {
  String toIQD() {
    final format = NumberFormat("#,##0", "en_US");
    return "${format.format(this)} IQD";
  }
}
"""
        with open(theme_path, "w", encoding="utf-8") as f:
            f.write(theme_content)
        print("Updated theme.dart with CurrencyFormatter extension.")

    # 2. Update other dart files
    count = 0
    pattern = r'\\*\$\{\s*(.+?)\s*\.toStringAsFixed\(2\)\}'
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"):
                continue
            path = os.path.join(root, file)
            # Skip theme.dart itself
            if file == "theme.dart":
                continue
                
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                
            original = content
            
            # Replace \$0.00 with 0 IQD in pos_screen.dart
            if file == "pos_screen.dart":
                content = content.replace(r"\'\\$0.00\'", r"\'0 IQD\'")
                content = content.replace(r"'\\$0.00'", r"'0 IQD'")
                content = content.replace(r"'\$0.00'", r"'0 IQD'")
                
            # Perform regex substitution for other dollar formats
            content = re.sub(pattern, r'${\1.toIQD()}', content)
            
            # Check if any replacement happened
            if content != original:
                # Check if theme.dart is imported
                if "theme/theme.dart" not in content:
                    # Insert import at the top of the file
                    lines = content.splitlines()
                    import_idx = 0
                    for idx, line in enumerate(lines):
                        if line.startswith("import "):
                            import_idx = idx
                            break
                    lines.insert(import_idx, "import 'package:sanare/theme/theme.dart';")
                    content = "\n".join(lines) + "\n"
                    
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Migrated currency in: {file}")
                count += 1
                
    print(f"Currency migration completed. Updated {count} files.")

if __name__ == "__main__":
    migrate()
