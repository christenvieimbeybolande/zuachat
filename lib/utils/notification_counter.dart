class NotificationCounter {
  static int unreadNotifications = 0;
  static int unreadMessages = 0;

  static void update({
    int? notifications,
    int? messages,
  }) {
    if (notifications != null) {
      unreadNotifications = notifications;
    }
    if (messages != null) {
      unreadMessages = messages;
    }
  }
}
