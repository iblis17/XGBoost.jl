using XGBoost

# we load in the agaricus dataset
# In this example, we are aiming to predict whether a mushroom can be eated
function readlibsvm(fname::ASCIIString, shape)
    dmx = zeros(Float32, shape)
    label = Float32[]
    fi = open(fname, "r")
    cnt = 1
    for line in eachline(fi)
        line = split(line, " ")
        push!(label, float(line[1]))
        line = line[2:end]
        for itm in line
            itm = split(itm, ":")
            dmx[cnt, int(itm[1]) + 1] = float(int(itm[2]))
        end
        cnt += 1
    end
    close(fi)
    return (dmx, label)
end

# we use auxiliary function to read LIBSVM format into julia Matrix
train_X, train_Y = readlibsvm("../data/agaricus.txt.train", (6513, 126))
test_X, test_Y = readlibsvm("../data/agaricus.txt.test", (1611, 126))

#-------------Basic Training using XGBoost-----------------
# note: xgboost naturally handles sparse input
# use sparse matrix when your feature is sparse(e.g. when you using one-hot encoding vector)
# model parameters can be set as parameters for ```xgboost``` function, or use a Vector{String} / Dict()
num_round = 2

print("training xgboost with dense matrix\n")
# you can directly pass Julia's matrix or sparse matrix as data,
# by calling xgboost(data, num_round, label=label, training-parameters)
bst = xgboost(train_X, num_round, label = train_Y, eta = 1, max_depth = 2,
              objective = "binary:logistic")


print("training xgboost with sparse matrix\n")
sptrain = sparse(train_X)
# alternatively, you can pass parameters in as a map
param = ["max_depth" => 2,
         "eta" => 1,
         "objective" => "binary:logistic"]
bst = xgboost(sptrain, num_round, label = train_Y, param = param)

# you can also put in xgboost's DMatrix object
# DMatrix stores label, data and other meta datas needed for advanced features
print("training xgboost with DMatrix\n")
dtrain = DMatrix(train_X, label = train_Y)
bst = xgboost(dtrain, num_round, eta = 1, objective = "binary:logistic")

# you can also specify data as file path to a LibSVM format input
bst = xgboost("../data/agaricus.txt.train", num_round, max_depth = 2, eta = 1,
              objective = "binary:logistic")

#--------------------basic prediction using XGBoost--------------
# you can do prediction using the following line
# you can put in Matrix, SparseMatrix or DMatrix
preds = predict(bst, test_X)
print("test-error=", sum((preds .> 0.5) .!= test_Y) / float(size(preds)[1]), "\n")

#-------------------save and load models-------------------------
# save model to binary local file
save(bst, "xgb.model")
# load binary model to julia
bst2 = Booster(model_file = "xgb.model")
preds2 = predict(bst2, test_X)
print("sum(abs(pred2-pred))=", sum(abs(preds2 .- preds)), "\n")

#----------------Advanced features --------------
# to use advanced features, we need to put data in xgb.DMatrix
dtrain = DMatrix(train_X, label = train_Y)
dtest = DMatrix(test_X, label = test_Y)

#---------------Using watchlist----------------
# watchlist is a list of DMatrix, each of them tagged with name
# DMatrix in watchlist should have label (for evaluation)
watchlist  = [(dtest,"eval"), (dtrain,"train")]
# we can change evaluation metrics, or use multiple evaluation metrics
bst = xgboost(dtrain, num_round, param = param, watchlist = watchlist,
              metrics = ["logloss", "error"])

# we can also save DMatrix into binary file, then we can load it faster next time
save(dtest, "dtest.buffer")
save(dtrain, "dtrain.buffer")

# load model and data
dtrain = DMatrix("dtrain.buffer")
dtest = DMatrix("dtest.buffer")
bst = Booster(model_file = "xgb.model")

# information can be extracted from DMatrix using get_info
label = get_info(dtest, "label")
pred = predict(bst, dtest)
print("test-error=", sum((pred .> 0.5) .!= label) / float(size(pred)[1]), "\n")

# Finally, you can dump the tree you learned using dump_model into a text file
dump_model(bst, "dump.raw.txt")
# If you have feature map file, you can dump the model in a more readable way
dump_model(bst, "dump.nice.txt", fmap = "../data/featmap.txt")
