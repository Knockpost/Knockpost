import os
import re

lib_dir = 'd:\\project\\KnockPost\\lib'

pattern = re.compile(r'CircularProgressIndicator\s*\([^)]*\)')

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'CircularProgressIndicator' not in content:
        return

    if 'knockpost_refresh.dart' in filepath.replace('\\', '/'):
        return

    def replacer(match):
        inner_args = match.group(0)
        if 'value:' in inner_args:
            return inner_args
        return 'const KnockPostLoadingIndicator()'

    new_content = pattern.sub(replacer, content)

    # Clean up double consts
    new_content = new_content.replace('const const KnockPostLoadingIndicator', 'const KnockPostLoadingIndicator')

    if 'KnockPostLoadingIndicator' in new_content and 'KnockPostLoadingIndicator' not in content:
        import_stmt = "import 'package:knockpost/widgets/knockpost_refresh.dart';"
        if import_stmt not in new_content:
            # Add the import right after the first line that looks like an import
            lines = new_content.split('\n')
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    lines.insert(i + 1, import_stmt)
                    new_content = '\n'.join(lines)
                    break

    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Updated {filepath}')

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
