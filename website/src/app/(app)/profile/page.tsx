"use client";

import { useState } from "react";
import styles from "./profile.module.css";
import { Settings, Menu } from "lucide-react";

export default function ProfilePage() {
  const [activeTab, setActiveTab] = useState("Recents");
  
  const mockPosts = Array.from({ length: 12 }).map((_, i) => ({
    id: i,
    url: `https://picsum.photos/seed/${i + 20}/300/300`,
  }));

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.header}>
        <div className={styles.avatarRow}>
          <div className={styles.avatar}></div>
          <div className={styles.stats}>
            <div className={styles.statItem}>
              <span className={styles.statValue}>12</span>
              <span className={styles.statLabel}>Posts</span>
            </div>
            <div className={styles.statItem}>
              <span className={styles.statValue}>402</span>
              <span className={styles.statLabel}>Followers</span>
            </div>
            <div className={styles.statItem}>
              <span className={styles.statValue}>291</span>
              <span className={styles.statLabel}>Following</span>
            </div>
          </div>
        </div>
        
        <div className={styles.bioSection}>
          <h2 className={styles.username}>username</h2>
          <p className={styles.bio}>Digital creator 📷<br/>Living life one pixel at a time.</p>
        </div>

        <div className={styles.actionButtons}>
          <button className={styles.editBtn}>Edit Profile</button>
          <button className={styles.settingsBtn}>
            <Settings size={20} />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className={styles.tabsContainer}>
        {["Recents", "Showcase", "Thoughts"].map((tab) => (
          <button 
            key={tab}
            className={`${styles.tabBtn} ${activeTab === tab ? styles.activeTab : ""}`}
            onClick={() => setActiveTab(tab)}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Grid */}
      <div className={styles.gridContainer}>
        {mockPosts.map((post) => (
          <div key={post.id} className={styles.gridItem}>
            <div 
              className={styles.image}
              style={{ backgroundImage: `url(${post.url})` }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
