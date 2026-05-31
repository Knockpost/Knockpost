"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "./Sidebar.module.css";
import { 
  Home, 
  Search, 
  Compass, 
  Clapperboard, 
  MessageCircle, 
  Heart, 
  PlusSquare, 
  User 
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();

  const navItems = [
    { name: "Home", href: "/feed", icon: Home },
    { name: "Search", href: "/search", icon: Search },
    { name: "Waves", href: "/waves", icon: Clapperboard },
    { name: "Messages", href: "/messages", icon: MessageCircle },
    { name: "Notifications", href: "/notifications", icon: Heart },
    { name: "Profile", href: "/profile", icon: User },
  ];

  return (
    <aside className={styles.sidebar}>
      <Link href="/feed" className={styles.logo}>
        KnockPost
      </Link>
      
      <nav className={styles.nav}>
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          const Icon = item.icon;
          
          return (
            <Link 
              key={item.name} 
              href={item.href} 
              className={`${styles.navItem} ${isActive ? styles.active : ""}`}
            >
              <Icon 
                className={styles.icon} 
                strokeWidth={isActive ? 2.5 : 2} 
                size={26}
              />
              <span className={styles.label}>{item.name}</span>
            </Link>
          );
        })}
      </nav>
      
      <div className={styles.bottomActions}>
        <Link href="/" className={styles.navItem}>
          <span className={styles.label}>Log Out</span>
        </Link>
      </div>
    </aside>
  );
}
