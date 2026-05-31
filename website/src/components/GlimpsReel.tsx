"use client";

import styles from "./GlimpsReel.module.css";
import { Plus } from "lucide-react";

interface Glimps {
  id: string;
  username: string;
  hasUnseen: boolean;
  isSelf?: boolean;
}

const mockGlimpses: Glimps[] = [
  { id: "1", username: "Your Story", hasUnseen: false, isSelf: true },
  { id: "2", username: "alex", hasUnseen: true },
  { id: "3", username: "sam_photo", hasUnseen: true },
  { id: "4", username: "traveler", hasUnseen: true },
];

export default function GlimpsReel() {
  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.title}>✨ Glimpses</h2>
        <button className={styles.addBtn}>
          <Plus size={20} color="#fff" />
        </button>
      </div>
      
      <div className={styles.reelContainer}>
        {mockGlimpses.map((glimps) => (
          <div key={glimps.id} className={styles.glimpsCard}>
            <div className={styles.thumbnail}></div>
            <div className={styles.glimpsInfo}>
              <div className={styles.avatar}></div>
              <span className={styles.username}>{glimps.username}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
