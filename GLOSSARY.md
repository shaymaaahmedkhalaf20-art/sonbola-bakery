# Al-Sonbola Bakery

A single bakery in Port Fouad that shows its menu online, takes orders from customers, and answers their questions. Arabic labels in parentheses are the words the site shows.

## People

**Customer** (الزبون):
A person who places an Order or sends a Message. A Customer may order without signing in, identified only by the name and mobile number they enter.
_Avoid_: User, client, visitor, guest

**Signed-in Customer** (زبون داخل بحسابه):
A Customer who has signed in with their email, so their Orders are linked to them and their name, mobile number and address are remembered. Signing in is never required to order.
_Avoid_: Member, registered user, account holder

**My Orders** (طلباتي):
The list of a Signed-in Customer's own Orders with each Order's current Order Status.
_Avoid_: Order history, account page

**Admin** (الأدمن):
A bakery staff member who signs in to the dashboard. All Admins have the same full access, and an Admin is only ever added by hand, never by signing up on the site.
_Avoid_: Owner, staff user, manager

## Menu

**Product** (صنف):
One item on the menu, with a name, a price per Sale Unit, and a Category.
_Avoid_: Item, menu item, SKU

**Category** (قسم):
A group of Products shown together on the menu, such as bread, pastries, and sweets.
_Avoid_: Section, menu group, type

**Sale Unit** (وحدة البيع):
What one counted unit of a Product means: a piece, a bundle, a pack, or a kilo. Every Product has exactly one.
_Avoid_: Measure, size

**Quantity Step**:
The smallest amount of a Product's Sale Unit that a Customer can order, such as 1 piece or ¼ kilo.
_Avoid_: Increment, minimum

**Unavailable** (خلص النهارده):
A Product that stays on the menu but cannot be ordered right now. It is not a deleted Product.
_Avoid_: Out of stock, sold out, hidden, disabled

## Ordering

**Order** (طلب):
A Customer's request for one or more Products, paid in cash at Pickup or on Delivery.
_Avoid_: Purchase, cart, booking

**Order Line**:
One Product in an Order, with its quantity and the price at the moment the Order was placed. An Admin can change the Order Lines while the Order is New or Accepted, and not after.
_Avoid_: Order item, line item, cart item

**Pickup** (استلام من المحل):
An Order that the Customer collects from the bakery.
_Avoid_: Takeaway, collection

**Delivery** (توصيل):
An Order that the bakery brings to the Customer's address in Port Fouad.
_Avoid_: Shipping, dispatch

**Delivery Fee** (مصاريف التوصيل):
One flat amount added to every Delivery Order, set by an Admin. It can be zero.
_Avoid_: Shipping cost, delivery charge

**Order Number** (رقم الطلب):
The short number a Customer and an Admin use to refer to one Order on the phone.
_Avoid_: Order ID, reference, code

**Opening Hours** (المواعيد):
The daily time window, in Cairo time, when the bakery is open and Customers can place Orders.
_Avoid_: Business hours, working hours, schedule

**Ordering Paused** (الطلبات متوقفة مؤقتاً):
A state an Admin switches on to stop new Orders, even during Opening Hours.
_Avoid_: Closed, holiday mode, shop off

**Open Order**:
An Order that is neither Completed nor Cancelled. A mobile number can have at most three at once.
_Avoid_: Active order, pending order

### Order Status

Every Order is in exactly one status, and only an Admin moves it forward.

**New** (جديد):
An Order the Customer has placed and no Admin has confirmed yet.

**Accepted** (اتأكد):
An Order an Admin has confirmed with the Customer and the bakery is preparing.
_Avoid_: Confirmed, in progress, processing

**Ready** (جاهز):
A Pickup Order waiting at the bakery for the Customer.

**Out for Delivery** (خرج للتوصيل):
A Delivery Order on its way to the Customer.
_Avoid_: Shipped, dispatched

**Completed** (اتسلّم):
An Order the Customer has received and paid for.
_Avoid_: Done, delivered, closed, fulfilled

**Cancelled** (اتلغى):
An Order an Admin has stopped before it was Completed. A Customer cannot cancel from the site.
_Avoid_: Rejected, void, deleted

## Contact

**Message** (رسالة):
A question or comment a Customer sends through the contact form. A Message is never an Order.
_Avoid_: Inquiry, contact request, ticket

**Handled** (اتعامل معاها):
A Message that an Admin has dealt with, usually by phone.
_Avoid_: Read, resolved, closed, answered
