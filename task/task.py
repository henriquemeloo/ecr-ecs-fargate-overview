import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("id")
    args = parser.parse_args()
    print(args.id)
