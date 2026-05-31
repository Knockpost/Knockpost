"use client";

import { Search as SearchIcon } from "lucide-react";
import styles from "./search.module.css";

export default function SearchPage() {
  const mockImages = Array.from({ length: 15 }).map((_, i) => ({
    id: i,
    url: `https://picsum.photos/seed/${i + 10}/300/300`,
    isLarge: i % 5 === 0 // Make some items large to create a staggered effect
  }));

  return (
    <div className={styles.container}>
      <div className={styles.searchBarContainer}>
        <div className={styles.searchBox}>
          <SearchIcon size={20} className={styles.searchIcon} />
          <input 
            type="text" 
            placeholder="Search for people or posts..." 
            className={styles.searchInput}
          />
        </div>
      </div>

      <div className={styles.gridContainer}>
        {mockImages.map((img) => (
          <div 
            key={img.id} 
            className={`${styles.gridItem} ${img.isLarge ? styles.largeItem : ""}`}
          >
            <div 
              className={styles.image}
              style={{ backgroundImage: `url(${img.url})` }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
