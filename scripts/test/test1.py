# 原始代码
class Student():
    def __init__(self, student_list):
        self.student_list = student_list


student = Student(['Alex', 'Amily', 'Linda'])
for i in student.student_list:
    print(i)


# __getitem__方法，让学生类具有了序列特征

class Student():
    def __init__(self, student_list):
        self.student_list = student_list

    def __getitem__(self, item):
        return self.student_list[item]


student = Student(['Alex', 'Amily', 'Linda'])
for stu in student:
    print(stu)

# getitem还具有序列属性，不然实例是没有迭代属性的，for循环必须要获取到一个
# 迭代器才能进行数据的迭代
print(student[1])