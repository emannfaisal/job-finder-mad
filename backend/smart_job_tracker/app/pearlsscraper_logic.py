from playwright.sync_api import sync_playwright
from .base_scraper import BaseScraper

class TenPearlsScraper(BaseScraper):
    def scrape(self):
        jobs = []

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=False)
            page = browser.new_page()
            locations=["karachi", "lahore", "islamabad"]
            for location in locations:
                page.goto(f"https://10pearls.com/{location}-job-openings/")

                # Wait for job cards
                page.wait_for_selector(".job-card")

                cards = page.locator(".job-card")

                for i in range(cards.count()):
                    card = cards.nth(i)

                    title = card.locator(".job-title").inner_text()
                    job_location = card.locator(".job-location").inner_text()
                    link = card.locator(".apply-link").get_attribute("href")

                    jobs.append({
                        "title": title.strip(),
                        "location": job_location.strip(),
                        "remote": "remote" in title.lower() or "remote" in job_location.lower(),
                        "link": link
                    })

            browser.close()

        return jobs

def scrape_10pearls():
    scraper = TenPearlsScraper("10Pearls")
    return scraper.scrape()




