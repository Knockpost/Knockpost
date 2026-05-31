"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "./BottomNav.module.css";
import { 
  Home, 
  Search, 
  MessageSquare,
  User 
} from "lucide-react";

const WavesIcon = ({ size = 24, strokeWidth = 2, className = "" }: any) => (
  <svg 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth={strokeWidth} 
    strokeLinecap="round" 
    strokeLinejoin="round" 
    className={className}
  >
    <rect x="2" y="5" width="20" height="14" rx="2" />
    <path d="M2 10h20" />
    <path d="M7 5v5" />
    <path d="M12 5v5" />
    <path d="M17 5v5" />
  </svg>
);

export default function BottomNav() {
  const pathname = usePathname();

  const navItems = [
    { name: "Home", href: "/feed", icon: Home },
    { name: "Search", href: "/search", icon: Search },
    { name: "Waves", href: "/waves", icon: WavesIcon },
    { name: "Messages", href: "/messages", icon: MessageSquare },
    { name: "Profile", href: "/profile", icon: User },
  ];

  return (
    <nav className={styles.bottomNav}>
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
              size={24}
            />
          </Link>
        );
      })}
    </nav>
  );
}
