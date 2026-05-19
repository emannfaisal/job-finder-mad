from abc import ABC, abstractmethod

class BaseScraper(ABC):
    def __init__(self, name):
        self.name = name

    @abstractmethod
    def scrape(self):
        pass

    def normalize(self, job):
        return {
            "title": job.title.strip(),
            "location": job.location.strip(),
            "remote": job.remote,
            "link": job.link,
            "source": self.name
        }