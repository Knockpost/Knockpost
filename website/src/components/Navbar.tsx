import Link from "next/link";
import styles from "./Navbar.module.css";

export default function Navbar() {
  return (
    <nav className={`${styles.navbar} glass`}>
      <div className={styles.container}>
        <Link href="/" className={styles.logo}>
          KnockPost
        </Link>
        <div className={styles.links}>
          <Link href="/about" className={styles.link}>About</Link>
          <Link href="/support" className={styles.link}>Support</Link>
        </div>
        <div className={styles.actions}>
          <Link href="/login" className={styles.loginBtn}>Log In</Link>
          <Link href="/signup" className={styles.signupBtn}>Sign Up</Link>
        </div>
      </div>
    </nav>
  );
}
