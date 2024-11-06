UPDATE employee
SET hire_date = '2016-01-14'
WHERE employee_id = 9;

ALTER TABLE customer
ADD FOREIGN KEY(support_rep_id)
REFERENCES employee(employee_id)
ON DELETE SET NULL;

ALTER TABLE invoice
ADD FOREIGN KEY(customer_id)
REFERENCES customer(customer_id)
ON DELETE SET NULL;

ALTER TABLE invoice_line
ADD FOREIGN KEY(invoice_id)
REFERENCES invoice(invoice_id)
ON DELETE SET NULL;

ALTER TABLE invoice_line
ADD FOREIGN KEY(track_id)
REFERENCES track(track_id)
ON DELETE SET NULL;

ALTER TABLE playlist_track
ADD FOREIGN KEY(playlist_id)
REFERENCES playlist(playlist_id)
ON DELETE CASCADE;

ALTER TABLE playlist_track
ADD FOREIGN KEY(track_id)
REFERENCES track(track_id)
ON DELETE CASCADE;

ALTER TABLE album
ADD FOREIGN KEY(artist_id)
REFERENCES artist(artist_id)
ON DELETE SET NULL;


ALTER TABLE playlist_track
ADD PRIMARY KEY(playlist_id, track_id);

##-----------------------------------Questions-----------------------------------------------

##-------------EASY QUESTIONS--------------------------------------------------------------------

## Who is the senior most employee in the company based on job title?
SELECT * FROM employee
ORDER BY levels DESC;
## --> Madan Mohan

## Which countries have the most invoices?
SELECT COUNT(*) AS c, billing_country 
FROM invoice
GROUP BY billing_country
ORDER BY c DESC;
## --> USA

## What are top 3 values of total invoice?
SELECT total FROM invoice
ORDER BY total DESC
LIMIT 3;
## --> 23.76, 19.8, 19.8

## Best city? Highest sum of invoice totals (city name and total)
SELECT SUM(total) as invoice_total, billing_city
FROM invoice
GROUP BY billing_city
ORDER BY invoice_total DESC;
## --> Prague, 273.24

## Best customer? (Customer with most money)
SELECT customer.customer_id, customer.first_name, customer.last_name, SUM(invoice.total) as money
FROM customer
JOIN invoice ON customer.customer_id = invoice.customer_id
GROUP BY customer.customer_id
ORDER BY money DESC
LIMIT 1;

SELECT * FROM artist;


##----------------MODERATE QUESTIONS--------------------------------
## Return email, first name, last name and genre of all rock music listeners 
##(list returned ordered alphabetically by email (ascending))
SELECT DISTINCT email, first_name, last_name 
FROM customer
JOIN invoice ON invoice.customer_id = customer.customer_id 
JOIN invoice_line ON invoice_line.invoice_id = invoice.invoice_id
WHERE track_id IN(
    SELECT track_id FROM track
    JOIN genre ON genre.genre_id = track.genre_id
    WHERE genre.name = 'Rock'
)

ORDER BY email;

## return artist name and total track count of top 10 rock bands
SELECT artist.artist_id, artist.name, COUNT(artist.artist_id) as track_count 
FROM track
JOIN album ON track.album_id = album.album_id
JOIN artist ON album.artist_id = artist.artist_id
JOIN genre ON genre.genre_id = track.genre_id
WHERE genre.name = 'Rock'
GROUP BY artist.artist_id
ORDER BY track_count DESC
LIMIT 10;

## Return track names having song length longer than avg song length. Return name and ms of each track
## Order by song length with longest song first 
SELECT name, milliseconds
FROM track
WHERE milliseconds>(
    SELECT AVG(milliseconds) FROM track
)
ORDER BY milliseconds DESC;

##----------------ADVANCED QUESTIONS-------------------------------------
## Q1. Return customer name, artist name and total amount spent by each customer on artists
# CTE (Common Table Expressions): Creates a temporary table for the duration of the query only
WITH best_selling_artist AS(
    SELECT artist.artist_id as artist_id, artist.name as artist_name, 
    SUM(invoice_line.unit_price*invoice_line.quantity) AS total_sales
    FROM invoice_line ## Used invoice line because of price and quantity columns as well as efficient join
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN album ON album.album_id = track.album_id
    JOIN artist ON artist.artist_id = album.artist_id
    GROUP BY 1          ## 1 and 3 are parameters taken in SELECT clause.
    ORDER BY 3 DESC     ## 1 here is artist.artist_id and 3 is total_sales
    LIMIT 1  ## Limit 1 because we wanted the 'best' artist, hence only 1 can be the best
)

SELECT c.customer_id, c.first_name, c.last_name, bsa.artist_name, SUM(il.unit_price*il.quantity) AS amount_spent
FROM invoice i
JOIN customer c ON c.customer_id = i.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN album alb ON alb.album_id = t.album_id
JOIN best_selling_artist bsa ON bsa.artist_id = alb.artist_id
GROUP BY 1,2,3,4
ORDER BY 5 DESC
## Best artist is 1 only, but buyers/customers of the best artist are many. These all are displayed here;

## Q2. Find out most popular music genre from each country (genre with highest amount of purchases)
WITH popular_genre AS(
    SELECT COUNT(invoice_line.quantity) AS purchases, customer.country, genre.name, genre.genre_id,
    ROW_NUMBER() OVER(PARTITION BY customer.country ORDER BY COUNT(invoice_line.quantity) DESC) AS row_no ## Row number assigns a number to a row and partition by determines on which parameter the row number is set
    FROM invoice_line                                                                                     ## Here, we want to check genre in a country. Hence, partition by country (eg, argentina has 1,2,3,4 purchase, then again australia has 1,2,3,4 purchase etc)
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON invoice.customer_id = customer.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY 2,3,4
    ORDER BY 2 ASC, 1 DESC
)
SELECT * FROM popular_genre WHERE row_no<=1;

## Alt soln for same question using recursion:
WITH RECURSIVE
    sales_per_country AS (
        SELECT COUNT(*) AS purchases_per_genre, customer.country, genre.name, genre.genre_id
        FROM invoice_line
        JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
        JOIN customer ON invoice.customer_id = customer.customer_id
        JOIN track ON track.track_id = invoice_line.track_id
        JOIN genre ON genre.genre_id = track.genre_id
        GROUP BY 2,3,4
        ORDER BY 2
    ),
    max_genre_per_country AS (SELECT MAX(purchases_per_genre) AS max_genre_number, country
    FROM sales_per_country
    GROUP BY 2
    ORDER BY 2)

SELECT * FROM sales_per_country
JOIN max_genre_per_country ON sales_per_country.country = max_genre_per_country.country
WHERE sales_per_country.purchases_per_genre = max_genre_per_country.max_genre_number;

## Determine which customer has spent the most on music from each country
## Return country, top customer, and total amount spent. For countries where top amount is shared, provide all customers with top amount
WITH RECURSIVE
    customer_with_country AS(
        SELECT customer.customer_id, first_name, last_name, billing_country, SUM(total) AS total_spending
        FROM invoice
        JOIN customer ON invoice.customer_id = customer.customer_id
        GROUP BY 1,2,3,4
        ORDER BY 2,3 DESC),

    country_max_spending AS(
        SELECT billing_country, MAX(total_spending) AS max_spending
        FROM customer_with_country
        GROUP BY billing_country)

SELECT cc.billing_country, cc.total_spending, cc.first_name, cc.last_name, cc.customer_id
FROM customer_with_country cc
JOIN country_max_spending ms
ON cc.billing_country = ms.billing_country
WHERE cc.total_spending = ms.max_spending
ORDER BY 1;

## Alt method, using CTE
WITH customer_with_country AS(
    SELECT customer.customer_id, customer.first_name, customer.last_name, billing_country, SUM(total) AS total_spending,
    ROW_NUMBER() OVER(PARTITION BY billing_country ORDER BY SUM(total) DESC) as row_no
    FROM invoice
    JOIN customer ON customer.customer_id = invoice.customer_id
    GROUP BY 1,2,3,4
    ORDER BY 4 ASC, 5 DESC)
SELECT * FROM customer_with_country WHERE row_no<=1