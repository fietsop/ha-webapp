test.py
def solution(typedText):
    upper_count = 0
    lower_count = 0
    
    # Iterate through each character in the input string
    for char in typedText:
        if char.isupper():
            upper_count += 1
        else:
            # The prompt guarantees only English letters
            lower_count += 1
            
    # Return the difference as specified
    return upper_count - lower_count