import os
import yaml
import glob
from string import Template

class Translator():
    def __init__(self, translations_folder='../loc', locale='en'):
        self.data = {}
        
        files = glob.glob(os.path.join(translations_folder, f'*.yaml'))
        for file in files:
            loc = os.path.splitext(os.path.basename(file))[0]
            with open(file, 'r', encoding='utf8') as f:
                self.data[loc] = yaml.safe_load(f)
                
        self.set_locale(locale)
                
    def set_locale(self, loc):
        if loc in self.data:
            self.locale = loc
        else:
            raise Exception(f"Invalid locale {loc}")
            
    def get_locale(self):
        return self.locale
    
    def translate(self, key, **kwargs):
        datatoken = self.data[self.get_locale()]
        for token in key.split('.'):
            datatoken = datatoken.get(token)
        return Template(datatoken).safe_substitute(**kwargs)