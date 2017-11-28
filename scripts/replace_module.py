import sys
import re

class Printing(object):
    PADDING = ' ' * 10
    SEPARATOR = '-' * 60
    DEFAULT = '\033[0m'
    COLORS = {
        'red': '\033[31m',
        'green': '\033[32m',
        'blue': '\033[94m',
        'lime': '\033[92m',
        }
    ATTRIBUTES = {
        'bold': '\033[1m',
        'underline': '\033[4m',
        'blink': '\033[5m',
        'reverse-video': '\033[7m',
        'concealed': '\033[8m',
        }

def colorize(color, text, attributes=None):
    attributes = attributes or ()
    attr_prefix = ''.join(Printing.ATTRIBUTES[attr] for attr in attributes)
    return attr_prefix + Printing.COLORS[color] + text + Printing.DEFAULT


class Replacer(object):
    def __init__(self, pattern, replacement):
        #self.pattern = pattern
        self.matcher = re.compile(pattern)
        self.replacement = replacement #re.compile(replacement)

    def match(self, s):
        return self.matcher.match(s)

    def apply(self, s):
        return re.sub(self.matcher, self.replacement, s)

class ModuleReplacer(object):
    def __init__(self, old_name, new_name):
        old_name = re.escape(old_name)

        self.replacers = []
        for quote in ['\'', '"']:
            pattern = '(.*)require +%s%s%s(.*)' % (quote, old_name, quote)
            rep = '\\1require \'%s\'\\2' % new_name
            self.replacers.append(Replacer(pattern, rep))

    def process_line(self, line):
        for replacer in self.replacers:
            if replacer.match(line):
                return replacer.apply(line)
        return line

if __name__ == '__main__':
    file_name, old_name, new_name = sys.argv[1:4]
    mr = ModuleReplacer(old_name, new_name)

    made_change = False
    new_lines = []
    with open(file_name) as f:
        for line in f:
            if line[-1] == '\n':
                line = line[:-1]
            new_line = mr.process_line(line)
            if new_line == line:
                new_lines.append(line)
                continue

            if not made_change:
                print 'In file %s:' % file_name

            print colorize('blue', '::: ', attributes=('bold',)), line
            print colorize('green', '>>> ', attributes=('bold',)), new_line
            resp = raw_input('Make replacement (y or n)? ')

            if resp == 'y':
                new_lines.append(new_line)
                made_change = True
            else:
                new_lines.append(line)

    if made_change:
        with open(file_name, 'w') as f:
            for line in new_lines:
                f.write(line + '\n')

    exit(0)

