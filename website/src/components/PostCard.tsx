"use client";

import styles from "./PostCard.module.css";
import { MoreHorizontal, SmilePlus, Undo2, Share2 } from "lucide-react";

interface PostProps {
  username: string;
  avatarUrl?: string;
  mediaUrl?: string;
  caption: string;
  likes: number;
  timeAgo: string;
}

export default function PostCard({ username, caption, timeAgo }: PostProps) {
  return (
    <article className={styles.postCard}>
      <header className={styles.header}>
        <div className={styles.headerLeft}>
          <div className={styles.avatar}></div>
          <div className={styles.headerInfo}>
            <span className={styles.username}>{username}</span>
            <span className={styles.time}>{timeAgo}</span>
          </div>
        </div>
        <button className={styles.moreBtn}>
          <MoreHorizontal size={20} color="#fff" />
        </button>
      </header>

      <div className={styles.mediaContainer}>
        {/* Placeholder for media */}
        <div className={styles.mediaPlaceholder}></div>
      </div>

      <div className={styles.footer}>
        <span className={styles.footerTime}>{timeAgo}</span>
        
        <div className={styles.actions}>
          <button className={styles.actionBtn}>
            <SmilePlus size={22} color="#fff" strokeWidth={1.5} />
          </button>
          <button className={styles.actionBtn}>
            <Undo2 size={22} color="#fff" strokeWidth={1.5} />
          </button>
          <button className={styles.actionBtn}>
            <Share2 size={22} color="#fff" strokeWidth={1.5} />
          </button>
        </div>
      </div>
    </article>
  );
}
