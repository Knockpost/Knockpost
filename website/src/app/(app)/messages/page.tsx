"use client";

import styles from "./messages.module.css";
import { Edit, Video, Phone, Info } from "lucide-react";

export default function MessagesPage() {
  const mockChats = [
    { id: 1, name: "alex_photography", lastMsg: "Sent an attachment", time: "2h", unread: true },
    { id: 2, name: "sam_smith", lastMsg: "Thanks for the feedback!", time: "5h", unread: false },
    { id: 3, name: "jordan.dev", lastMsg: "Are you going to the meetup?", time: "1d", unread: false },
  ];

  return (
    <div className={styles.container}>
      <div className={styles.sidebar}>
        <div className={styles.header}>
          <h2>my_username</h2>
          <Edit size={24} className={styles.icon} />
        </div>
        <div className={styles.chatList}>
          {mockChats.map((chat) => (
            <div key={chat.id} className={`${styles.chatItem} ${chat.unread ? styles.unread : ""}`}>
              <div className={styles.avatar}></div>
              <div className={styles.chatInfo}>
                <span className={styles.chatName}>{chat.name}</span>
                <span className={styles.lastMessage}>{chat.lastMsg} • {chat.time}</span>
              </div>
              {chat.unread && <div className={styles.unreadDot}></div>}
            </div>
          ))}
        </div>
      </div>
      
      <div className={styles.chatWindow}>
        <div className={styles.emptyState}>
          <div className={styles.emptyIcon}>
            <svg aria-label="Direct" color="currentColor" fill="currentColor" height="96" role="img" viewBox="0 0 96 96" width="96"><circle cx="48" cy="48" fill="none" r="47" stroke="currentColor" strokeLinejoin="round" strokeWidth="2"></circle><line fill="none" stroke="currentColor" strokeLinejoin="round" strokeWidth="2" x1="69.286" x2="41.447" y1="33.21" y2="48.804"></line><polygon fill="none" points="47.254 73.123 71.376 31.998 24.546 32.002 41.448 48.805 47.254 73.123" stroke="currentColor" strokeLinejoin="round" strokeWidth="2"></polygon></svg>
          </div>
          <h2>Your Messages</h2>
          <p>Send private photos and messages to a friend or group.</p>
          <button className={styles.sendMsgBtn}>Send Message</button>
        </div>
      </div>
    </div>
  );
}
