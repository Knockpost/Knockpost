"use client";

import Link from "next/link";
import { Bell } from "lucide-react";
import styles from "./TopNav.module.css";

export default function TopNav() {
  return (
    <header className={styles.topNav}>
      <Link href="/feed" className={styles.logo}>
        KnockPost
      </Link>
      <div className={styles.actions}>
        <button className={styles.actionBtn}>
          <Bell size={24} color="#fff" />
        </button>
      </div>
    </header>
  );
}
