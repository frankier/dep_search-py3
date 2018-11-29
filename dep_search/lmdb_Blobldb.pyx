# cython: language_level=3
# distutils: language = c++
from DB import BaseDB
import lmdb
cimport py_tree
import os
import copy

class DB(BaseDB):

    #
    def __init__(self, name):
        super().__init__(name)
        self.s=py_tree.Py_Tree()
        self.name = name
        self.blob = None

    #
    def open(self):
        #check if pickle exists
        try:
            os.mkdir(self.name)
        except:
            pass

        self.env = lmdb.open(self.name + '/lmdb/', max_dbs=2)
        self.blob_db = self.env.open_db(b'blob')
        self.set_db = self.env.open_db(b'sets')

        self.txn = self.env.begin(write=True)


    #
    def close(self):
        self.env.close()

    #
    def add_to_idx(self, comments, sent):
        # get set ids
        val = self.s.set_id_list_from_conllu(sent, comments, self)
        idx = self.get_count('sets_'.encode('utf8'))
        self.txn.put('sets_'.encode('utf8') + idx, str(val).encode('utf8'), db=b'sets')
        self.txn.commit()
        return idx

    #
    def has_id(self, idx):
        return self.txn.get(('tag_' + idx).encode('utf8'), default=None, db=b'sets') != None
    #
    def get_id_for(self, idx):
        return int(self.txn.get(('tag_' + idx).encode('utf8')), default=None, db=b'sets')

    #
    def store_a_vocab_item(self, item):
        if not self.has_id(item):
            self.txn.put(('tag_' + item).encode('utf8'), self.get_count('tag_'), db=b'sets')
            self.txn.commit()
    #
    def store_blob(self, blob, blob_idx):
        #print (('blob_' + str(blob_idx)).encode('utf8'))
        if isinstance(blob_idx, int):
            blob_idx = str(blob_idx).encode('utf8')
        elif isinstance(blob_idx, str):
            blob_idx = blob_idx.encode('utf8')

            

        self.txn.put(('blob_'.encode('utf8') + blob_idx), blob, db=b'blob')
        self.txn.commit()
        return blob_idx

    #
    def get_blob(self, idx):
        #print (self.txn.get(('blob_' + str(idx)).encode('utf8')))
        self.blob = self.txn.get(('blob_' + str(idx)).encode('utf8'), default=None, db=b'blob')
        return self.blob

    #
    def finish_indexing(self):
        self.close()

    def get_count(self, pref):
        counter = 0

        if isinstance(pref, str):
            pref = pref.encode('utf8')
        cursor = self.txn.cursor()
        if not cursor.set_key(pref):
            return b'0'

        for key, value in enumerate(cursor.iternext_dup()):
            counter += 1
        return str(counter).encode('utf8')
