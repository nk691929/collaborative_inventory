My Awesome Inventory App (Built with a Little Help!)

I made this app to manage inventory with my team. It's built with Flutter and Riverpod and it handles things really smoothly, especially when the Wi-Fi is shaky. It looks simple, but there's a lot going on under the hood!

The Cool Stuff It Can Do

Login & Roles: I set up different users (Admin, Manager, Viewer) so everyone only sees and does what they're supposed to.

Super Fast Updates: When you change a stock number, the app updates instantly. If the internet is slow, it fixes itself later—this is called Optimistic UI.

Offline King: If you lose service, you can keep making changes! It saves everything into a Queue and syncs when you get back online.

Full History: There's a log for every product that shows exactly who changed the stock and when.

How to Get This Running on Your Computer (What I Did)

This part is pretty straightforward if you want to try it out:

Grab the Code:

git clone https://github.com/nk691929/collaborative_inventory.git
cd collaborative_inventory


Install the Parts:

flutter pub get


Run the Generator (This makes the Hive database stuff work):

flutter packages pub run build_runner build --delete-conflicting-outputs


Launch the App:

flutter run


Test Accounts I Made Up

I put these accounts in so you can test the different permissions:

Email

Password

Role

Can Do This

admin@example.com

admin123

Admin

Everything (Create, Edit, Delete, See History)

manager@example.com

manager123

Manager

View, Create, Edit Stock

viewer@example.com

viewer123

Viewer

View Only

The Brains Behind the Operation (What My Awesome AI Helper Did)

Okay, I'll be honest, my helper AI figured out the really tricky parts. I just put the pieces together where it and apply changes where i need it.

1. The Offline Queue System (The Magic)

It figured out how to use Hive (a local database) to store all the operations (like "add 5 to product X").

It designed the OfflineQueueService which is like a manager that watches the internet. If the internet is gone, it saves the operation. When the internet comes back, it automatically replays the whole list of changes!

It even added a smart limit to retry failed syncs only a few times before calling it a permanent issue.

2. Handling Conflicts (Avoiding Data Fights)

It came up with the Last-Writer-Wins (LWW) rule. This means if two people change the same item at the same time, the one with the newest timestamp wins.

It built a fake server (MockBackendService) that checks those timestamps and intentionally throws an error if someone's trying to use old data.

3. The Whole Structure

It designed the whole Riverpod framework, setting up the service layers and notifiers (like the InventoryManager) to make sure everything talks to each other correctly, especially between the instant UI updates and the slower network calls.