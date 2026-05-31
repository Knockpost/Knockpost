"use client";

import styles from "./waves.module.css";
import { Heart, MessageCircle, Send, MoreHorizontal } from "lucide-react";
import { useState } from "react";

export default function WavesPage() {
  const [isLiked, setIsLiked] = useState(false);

  return (
    <div className={styles.container}>
      <div className={styles.waveContainer}>
        {/* Video Placeholder */}
        <div className={styles.videoPlaceholder}>
          <div className={styles.videoOverlay}>
            <div className={styles.waveInfo}>
              <div className={styles.userInfo}>
                <div className={styles.avatar}></div>
                <span className={styles.username}>username</span>
                <button className={styles.followBtn}>Follow</button>
              </div>
              <p className={styles.caption}>This is a beautifully rendered wave 🌊 #knockpost</p>
            </div>
            
            <div className={styles.actionSidebar}>
              <div className={styles.actionItem} onClick={() => setIsLiked(!isLiked)}>
                <Heart size={28} className={isLiked ? styles.liked : ""} fill={isLiked ? "currentColor" : "none"} />
                <span>12.4K</span>
              </div>
              <div className={styles.actionItem}>
                <MessageCircle size={28} />
                <span>402</span>
              </div>
              <div className={styles.actionItem}>
                <Send size={28} />
              </div>
              <div className={styles.actionItem}>
                <MoreHorizontal size={28} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
