from pyspark.sql import SparkSession
import random

if __name__ == "__main__":
    spark = SparkSession.builder.appName("spark-pi").getOrCreate()
    sc = spark.sparkContext
    n = 1_000_000  # keep small for fast demo
    def inside(_):
        x, y = random.random(), random.random()
        return 1 if x*x + y*y <= 1 else 0
    count = sc.parallelize(range(n), numSlices=8).map(inside).reduce(lambda a,b: a+b)
    pi = 4.0 * count / n
    print(f"Pi is roughly {pi}")
    spark.stop()
