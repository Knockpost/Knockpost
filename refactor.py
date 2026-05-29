import os
import re

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                process_file(filepath)

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Replace App Title
    content = re.sub(
        r'TextStyle\(\s*color:\s*([^,]+),\s*fontWeight:\s*FontWeight\.w800,\s*fontSize:\s*21,\s*letterSpacing:\s*-0\.5,?\s*\)',
        r'AppTypography.appTitle.copyWith(color: \1)',
        content
    )

    # General replacements for w600 -> w700 to maintain visual parity if they don't match exactly
    content = content.replace('FontWeight.w600', 'FontWeight.w700')

    # General replacements for specific font sizes
    # fontSize: 16, fontWeight: w700 -> AppTypography.sectionHeader
    content = re.sub(
        r'TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w700\s*\)',
        r'AppTypography.sectionHeader',
        content
    )
    content = re.sub(
        r'TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w700,\s*color:\s*([^,]+)\s*\)',
        r'AppTypography.sectionHeader.copyWith(color: \1)',
        content
    )

    if content != original:
        import_stmt = "import '../theme/app_typography.dart';"
        
        if 'package:flutter/material.dart' in content and 'app_typography.dart' not in content:
            # We just add it blindly after material.dart. Since Dart imports can be absolute using package, let's use the package name.
            # Assuming the package name is something we don't know exactly, we'll try a relative import if we can, or just use package:knockpost
            pass

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

if __name__ == "__main__":
    process_directory('lib')
