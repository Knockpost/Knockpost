import Link from "next/link";
import styles from "./Footer.module.css";

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className={styles.footer}>
      <div className={styles.container}>
        <div className={styles.topSection}>
          <div className={styles.brand}>
            <h2 className={styles.logo}>KnockPost</h2>
            <p className={styles.tagline}>Share moments, connect with people, and discover meaningful content.</p>
          </div>
          <div className={styles.linksGrid}>
            <div className={styles.linkGroup}>
              <h3>Platform</h3>
              <Link href="/about">About</Link>
              <Link href="/support">Support</Link>
            </div>
            <div className={styles.linkGroup}>
              <h3>Legal</h3>
              <Link href="/privacy">Privacy Policy</Link>
              <Link href="/terms">Terms & Conditions</Link>
              <Link href="/guidelines">Community Guidelines</Link>
            </div>
          </div>
        </div>
        <div className={styles.bottomSection}>
          <p>&copy; {currentYear} KnockPost. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
