import styles from "./SuggestionsSidebar.module.css";
import Link from "next/link";

export default function SuggestionsSidebar() {
  return (
    <div className={styles.suggestionsContainer}>
      <div className={styles.currentUser}>
        <div className={styles.avatar}></div>
        <div className={styles.userInfo}>
          <span className={styles.username}>my_username</span>
          <span className={styles.fullName}>My Full Name</span>
        </div>
        <button className={styles.switchBtn}>Switch</button>
      </div>

      <div className={styles.suggestionsHeader}>
        <span className={styles.title}>Suggested for you</span>
        <button className={styles.seeAllBtn}>See All</button>
      </div>

      <div className={styles.suggestionList}>
        {[1, 2, 3, 4, 5].map((i) => (
          <div key={i} className={styles.suggestionItem}>
            <div className={styles.suggestionAvatar}></div>
            <div className={styles.suggestionInfo}>
              <span className={styles.suggestionUsername}>user_{i}</span>
              <span className={styles.suggestionReason}>New to KnockPost</span>
            </div>
            <button className={styles.followBtn}>Follow</button>
          </div>
        ))}
      </div>

      <div className={styles.footer}>
        <div className={styles.links}>
          <Link href="/about">About</Link>
          <Link href="/support">Help</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
        </div>
        <span className={styles.copyright}>© 2026 KNOCKPOST</span>
      </div>
    </div>
  );
}
