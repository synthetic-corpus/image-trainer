""""
    This file exists solely to
    verify if a work flow catches pep8
    formatting problems.
    We expect no formatting problems in this version.
"""


def myFunction(word: str) -> str:
    return_this = f'you said {word}'
    return return_this


print(myFunction('foo'))
print(myFunction(word="bar"))

my_array = ['foobar', 'fizzbar', 'barfoo']

mydict = {}
for w in my_array:
    myValue = myFunction(w)
    mydict[w] = myValue

print(mydict)
