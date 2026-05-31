import TopNav from "./TopNav";
import BottomNav from "./BottomNav";
import styles from "./AppShell.module.css";

export default function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className={styles.appShell}>
      <TopNav />
      <main className={styles.mainContent}>
        <div className={styles.contentWrapper}>
          {children}
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
