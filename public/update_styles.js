const fs = require('fs');
const path = require('path');

const files = ['privacy.html', 'terms.html', 'community-guidelines.html', 'support.html'];

const newStyle = `<style>
        :root {
            --bg-color: #18191A;
            --text-main: #E4E6EB;
            --text-muted: #B0B3B8;
            --primary: #2D88FF;
            --card-bg: #242526;
            --border: #3E4042;
            --font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        }

        body {
            font-family: var(--font-family);
            background-color: var(--bg-color);
            color: var(--text-main);
            line-height: 1.6;
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        .header {
            background-color: var(--card-bg);
            border-bottom: 1px solid var(--border);
            padding: 16px 24px;
            display: flex;
            align-items: center;
            justify-content: center;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        .header-logo {
            font-weight: 800;
            font-size: 1.25rem;
            color: var(--text-main);
            letter-spacing: -0.5px;
            text-decoration: none;
        }

        .container {
            max-width: 720px;
            margin: 48px auto;
            padding: 0 24px;
        }

        h1 {
            font-size: 2.25rem;
            font-weight: 800;
            margin-bottom: 8px;
            color: var(--text-main);
            letter-spacing: -0.02em;
        }

        .last-updated {
            font-size: 0.95rem;
            color: var(--text-muted);
            margin-bottom: 40px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--border);
        }

        h2 {
            font-size: 1.25rem;
            font-weight: 600;
            margin-top: 32px;
            margin-bottom: 16px;
            color: var(--text-main);
            letter-spacing: -0.01em;
        }

        p {
            margin-bottom: 16px;
            color: var(--text-muted);
            font-size: 1rem;
            line-height: 1.7;
        }

        ul {
            margin-bottom: 24px;
            padding-left: 24px;
            color: var(--text-muted);
        }

        li {
            margin-bottom: 12px;
            line-height: 1.6;
        }

        li::marker {
            color: var(--text-muted);
        }

        a {
            color: var(--primary);
            text-decoration: none;
            font-weight: 500;
        }

        a:hover {
            text-decoration: underline;
        }

        footer {
            margin-top: 80px;
            padding: 40px 24px;
            text-align: center;
            border-top: 1px solid var(--border);
            color: var(--text-muted);
            font-size: 0.9rem;
        }

        footer a {
            color: var(--text-muted);
            margin: 0 12px;
            font-weight: 400;
        }
        
        footer a:hover {
            color: var(--text-main);
        }

        @media (max-width: 768px) {
            .container {
                margin: 32px auto;
            }
            h1 {
                font-size: 1.75rem;
            }
        }
    </style>`;

files.forEach(file => {
    const filePath = path.join(__dirname, file);
    let content = fs.readFileSync(filePath, 'utf8');

    // Replace style block
    content = content.replace(/<style>[\s\S]*?<\/style>/, newStyle);

    // Add header if not present
    if (!content.includes('<header class="header">')) {
        content = content.replace('<body>', '<body>\n    <header class="header">\n        <a href="#" class="header-logo">Knockpost</a>\n    </header>');
    }

    // Add footer if not present
    if (!content.includes('<footer>')) {
        content = content.replace('</body>', '    <footer>\n        &copy; 2026 Knockpost. All rights reserved.<br><br>\n        <a href="privacy">Privacy</a>\n        <a href="terms">Terms</a>\n        <a href="community-guidelines">Guidelines</a>\n        <a href="support">Support</a>\n    </footer>\n</body>');
    }

    fs.writeFileSync(filePath, content);
    console.log('Updated ' + file);
});
