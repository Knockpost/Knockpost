"use client";

import styles from "./notifications.module.css";

export default function NotificationsPage() {
  const mockNotifications = [
    { id: 1, type: "like", text: "alex liked your photo.", time: "2h", avatar: "https://ui-avatars.com/api/?name=alex&background=random" },
    { id: 2, type: "comment", text: "jordan commented: 'Looks amazing!'", time: "5h", avatar: "https://ui-avatars.com/api/?name=jordan&background=random" },
    { id: 3, type: "follow", text: "sam started following you.", time: "1d", avatar: "https://ui-avatars.com/api/?name=sam&background=random" },
    { id: 4, type: "like", text: "traveler liked your post.", time: "2d", avatar: "https://ui-avatars.com/api/?name=traveler&background=random" },
  ];

  return (
    <div className={styles.container}>
      <h1 className={styles.headerTitle}>Notifications</h1>
      <div className={styles.list}>
        {mockNotifications.map((notif) => (
          <div key={notif.id} className={styles.notificationItem}>
            <div 
              className={styles.avatar} 
              style={{ backgroundImage: `url(${notif.avatar})` }}
            />
            <div className={styles.notifContent}>
              <span className={styles.notifText}>
                {notif.text}
              </span>
              <span className={styles.notifTime}>{notif.time}</span>
            </div>
            {notif.type === "follow" && (
              <button className={styles.followBtn}>Follow</button>
            )}
            {notif.type !== "follow" && (
              <div className={styles.postThumbnail} />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
